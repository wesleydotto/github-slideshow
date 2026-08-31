(function () {
  "use strict";

  const state = {
    busca: "",
    materia: "todas",
    nivel: "todos",
    etapa: "todas",
  };

  const grid = document.getElementById("grid-metodologias");
  const contagem = document.getElementById("contagem-resultados");
  const filtroMateria = document.getElementById("filtro-materia");
  const filtroNivel = document.getElementById("filtro-nivel");
  const filtroEtapa = document.getElementById("filtro-etapa");
  const campoBusca = document.getElementById("campo-busca");
  const modal = document.getElementById("modal");
  const modalConteudo = document.getElementById("modal-conteudo");
  const modalFechar = document.getElementById("modal-fechar");

  const trilhaMateria = document.getElementById("trilha-materia");
  const trilhaNivel = document.getElementById("trilha-nivel");
  const trilhaBtn = document.getElementById("trilha-gerar");
  const trilhaResultado = document.getElementById("trilha-resultado");
  const trilhaImprimir = document.getElementById("trilha-imprimir");

  function etapaInfo(id) {
    return ETAPAS.find((e) => e.id === id);
  }

  function popularSelects() {
    for (const materia of MATERIAS) {
      const opt1 = document.createElement("option");
      opt1.value = materia;
      opt1.textContent = materia;
      filtroMateria.appendChild(opt1);

      const opt2 = document.createElement("option");
      opt2.value = materia;
      opt2.textContent = materia;
      trilhaMateria.appendChild(opt2);
    }
    for (const nivel of NIVEIS) {
      const opt1 = document.createElement("option");
      opt1.value = nivel;
      opt1.textContent = nivel;
      filtroNivel.appendChild(opt1);

      const opt2 = document.createElement("option");
      opt2.value = nivel;
      opt2.textContent = nivel;
      trilhaNivel.appendChild(opt2);
    }
    for (const etapa of ETAPAS) {
      const opt = document.createElement("option");
      opt.value = etapa.id;
      opt.textContent = etapa.nome;
      filtroEtapa.appendChild(opt);
    }
  }

  function metodologiaCombina(m) {
    if (state.materia !== "todas" && !m.materias.includes(state.materia)) return false;
    if (state.nivel !== "todos" && !m.niveis.includes(state.nivel)) return false;
    if (state.etapa !== "todas" && m.etapa !== state.etapa) return false;
    if (state.busca.trim()) {
      const alvo = (m.nome + " " + m.resumo + " " + m.materias.join(" ")).toLowerCase();
      if (!alvo.includes(state.busca.trim().toLowerCase())) return false;
    }
    return true;
  }

  function criarCard(m) {
    const etapa = etapaInfo(m.etapa);
    const card = document.createElement("article");
    card.className = "card";
    card.tabIndex = 0;
    card.setAttribute("role", "button");
    card.setAttribute("aria-label", "Ver detalhes de " + m.nome);

    card.innerHTML = `
      <span class="card-etapa" style="--cor-etapa:${etapa.cor}">${etapa.nome}</span>
      <h3>${m.nome}</h3>
      <p class="card-resumo">${m.resumo}</p>
      <div class="card-tags">
        ${m.materias.slice(0, 3).map((t) => `<span class="tag">${t}</span>`).join("")}
        ${m.materias.length > 3 ? `<span class="tag tag-mais">+${m.materias.length - 3}</span>` : ""}
      </div>
      <div class="card-meta">
        <span>⏱ ${m.duracao}</span>
        <span>👥 ${m.tamanhoGrupo}</span>
      </div>
    `;

    const abrir = () => abrirModal(m);
    card.addEventListener("click", abrir);
    card.addEventListener("keydown", (ev) => {
      if (ev.key === "Enter" || ev.key === " ") {
        ev.preventDefault();
        abrir();
      }
    });

    return card;
  }

  function renderizarGrid() {
    const resultados = METODOLOGIAS.filter(metodologiaCombina);
    grid.innerHTML = "";
    if (resultados.length === 0) {
      grid.innerHTML = `<p class="vazio">Nenhuma metodologia encontrada com esses filtros. Tente ajustar a busca.</p>`;
    } else {
      for (const m of resultados) {
        grid.appendChild(criarCard(m));
      }
    }
    contagem.textContent = `${resultados.length} metodologia${resultados.length === 1 ? "" : "s"} encontrada${resultados.length === 1 ? "" : "s"}`;
  }

  function referenciaTexto(r) {
    return `${r.autor} (${r.ano}). ${r.titulo}.${r.fonte ? " " + r.fonte + "." : ""}`;
  }

  function detalheHTML(m) {
    const etapa = etapaInfo(m.etapa);
    return `
      <span class="card-etapa" style="--cor-etapa:${etapa.cor}">${etapa.nome}</span>
      <h2>${m.nome}</h2>
      <p class="modal-resumo">${m.resumo}</p>

      <h4>Como aplicar</h4>
      <ol>${m.comoAplicar.map((passo) => `<li>${passo}</li>`).join("")}</ol>

      <div class="modal-grid">
        <div>
          <h4>Matérias/temas</h4>
          <div class="card-tags">${m.materias.map((t) => `<span class="tag">${t}</span>`).join("")}</div>
        </div>
        <div>
          <h4>Nível de ensino</h4>
          <div class="card-tags">${m.niveis.map((t) => `<span class="tag tag-nivel">${t}</span>`).join("")}</div>
        </div>
      </div>

      <div class="modal-grid">
        <div>
          <h4>Duração</h4>
          <p>${m.duracao}</p>
        </div>
        <div>
          <h4>Tamanho do grupo</h4>
          <p>${m.tamanhoGrupo}</p>
        </div>
      </div>

      <h4>Materiais necessários</h4>
      <ul>${m.materiais.map((mat) => `<li>${mat}</li>`).join("")}</ul>

      <h4>Referências</h4>
      <ul class="referencias">${m.referencias.map((r) => `<li>${referenciaTexto(r)}</li>`).join("")}</ul>
    `;
  }

  function abrirModal(m) {
    modalConteudo.innerHTML = detalheHTML(m);
    modal.classList.add("aberto");
    modal.setAttribute("aria-hidden", "false");
    modalFechar.focus();
  }

  function fecharModal() {
    modal.classList.remove("aberto");
    modal.setAttribute("aria-hidden", "true");
  }

  modalFechar.addEventListener("click", fecharModal);
  modal.addEventListener("click", (ev) => {
    if (ev.target === modal) fecharModal();
  });
  document.addEventListener("keydown", (ev) => {
    if (ev.key === "Escape" && modal.classList.contains("aberto")) fecharModal();
  });

  filtroMateria.addEventListener("change", () => {
    state.materia = filtroMateria.value;
    renderizarGrid();
  });
  filtroNivel.addEventListener("change", () => {
    state.nivel = filtroNivel.value;
    renderizarGrid();
  });
  filtroEtapa.addEventListener("change", () => {
    state.etapa = filtroEtapa.value;
    renderizarGrid();
  });
  campoBusca.addEventListener("input", () => {
    state.busca = campoBusca.value;
    renderizarGrid();
  });

  // ---- Gerador de trilha de aprendizagem ----

  function metodologiaServeParaTrilha(m, materia, nivel) {
    const materiaOk = materia === "todas" || m.materias.includes(materia) || m.materias.includes("Geral");
    const nivelOk = nivel === "todos" || m.niveis.includes(nivel);
    return materiaOk && nivelOk;
  }

  function gerarTrilha(materia, nivel) {
    const etapasOrdenadas = ETAPAS.map((e) => e.id);
    const trilha = [];

    for (const etapaId of etapasOrdenadas) {
      const candidatas = METODOLOGIAS.filter(
        (m) => m.etapa === etapaId && metodologiaServeParaTrilha(m, materia, nivel)
      );
      if (candidatas.length === 0) continue;

      // Prioriza metodologias específicas da matéria escolhida em vez de "Geral".
      candidatas.sort((a, b) => {
        const aEspecifica = materia !== "todas" && a.materias.includes(materia) ? 0 : 1;
        const bEspecifica = materia !== "todas" && b.materias.includes(materia) ? 0 : 1;
        return aEspecifica - bEspecifica;
      });

      trilha.push(candidatas[0]);
    }

    return trilha;
  }

  function renderizarTrilha(trilha, materia, nivel) {
    if (trilha.length === 0) {
      trilhaResultado.innerHTML = `<p class="vazio">Não encontramos metodologias suficientes para essa combinação. Tente "Todas as matérias" ou "Todos os níveis".</p>`;
      trilhaImprimir.hidden = true;
      return;
    }

    const tituloMateria = materia === "todas" ? "Ciências (geral)" : materia;
    const tituloNivel = nivel === "todos" ? "todos os níveis" : nivel;

    let html = `<h3 class="trilha-titulo">Trilha sugerida — ${tituloMateria} <span class="trilha-nivel-badge">${tituloNivel}</span></h3>`;
    html += `<ol class="trilha-linha-do-tempo">`;
    for (const m of trilha) {
      const etapa = etapaInfo(m.etapa);
      html += `
        <li class="trilha-passo" style="--cor-etapa:${etapa.cor}">
          <div class="trilha-passo-etapa">${etapa.nome}</div>
          <div class="trilha-passo-nome">${m.nome}</div>
          <p class="trilha-passo-resumo">${m.resumo}</p>
          <div class="card-meta">
            <span>⏱ ${m.duracao}</span>
            <span>👥 ${m.tamanhoGrupo}</span>
          </div>
          <button type="button" class="link-detalhes" data-id="${m.id}">Ver detalhes completos →</button>
        </li>
      `;
    }
    html += `</ol>`;

    trilhaResultado.innerHTML = html;
    trilhaImprimir.hidden = false;

    trilhaResultado.querySelectorAll(".link-detalhes").forEach((btn) => {
      btn.addEventListener("click", () => {
        const m = METODOLOGIAS.find((x) => x.id === btn.dataset.id);
        if (m) abrirModal(m);
      });
    });
  }

  trilhaBtn.addEventListener("click", () => {
    const materia = trilhaMateria.value;
    const nivel = trilhaNivel.value;
    const trilha = gerarTrilha(materia, nivel);
    renderizarTrilha(trilha, materia, nivel);
  });

  trilhaImprimir.addEventListener("click", () => window.print());

  // ---- inicialização ----
  popularSelects();
  renderizarGrid();
})();
