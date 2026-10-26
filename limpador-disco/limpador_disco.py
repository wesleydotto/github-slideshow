"""
Limpador de Disco - encontra arquivos e pastas grandes e os envia para a Lixeira.

Requisitos: Python 3.8+ e o pacote send2trash (pip install send2trash).
Execute: python limpador_disco.py
"""
import os
import queue
import subprocess
import sys
import threading
import time
import tkinter as tk
from tkinter import filedialog, messagebox, ttk

try:
    from send2trash import send2trash
except ImportError:
    send2trash = None

MAX_ARQUIVOS = 500
MAX_PASTAS = 300
MARCADO, DESMARCADO = "☑", "☐"


def formatar_tamanho(n):
    for unidade in ("B", "KB", "MB", "GB", "TB"):
        if n < 1024 or unidade == "TB":
            return f"{n:.0f} {unidade}" if unidade == "B" else f"{n:.1f} {unidade}"
        n /= 1024


def e_link(entry):
    # Ignora atalhos simbólicos e junções do Windows para não contar nada duas vezes.
    if entry.is_symlink():
        return True
    is_junction = getattr(entry, "is_junction", None)
    return bool(is_junction and is_junction())


def escanear(raiz, tamanho_min, fila, cancelar):
    """Percorre a pasta e envia o resultado para a fila: (arquivos, pastas)."""
    arquivos = []
    tamanho_pastas = {}
    pilha = [raiz]
    contador = 0
    ultimo_aviso = time.time()

    while pilha:
        if cancelar.is_set():
            fila.put(("cancelado", None))
            return
        pasta = pilha.pop()
        total_local = 0
        try:
            with os.scandir(pasta) as it:
                for entry in it:
                    try:
                        if e_link(entry):
                            continue
                        if entry.is_dir(follow_symlinks=False):
                            pilha.append(entry.path)
                        elif entry.is_file(follow_symlinks=False):
                            st = entry.stat(follow_symlinks=False)
                            total_local += st.st_size
                            contador += 1
                            if st.st_size >= tamanho_min:
                                arquivos.append((st.st_size, entry.path, st.st_mtime))
                    except OSError:
                        continue
        except OSError:
            continue

        # Soma o tamanho desta pasta em todas as pastas acima dela, até a raiz.
        p = pasta
        while True:
            tamanho_pastas[p] = tamanho_pastas.get(p, 0) + total_local
            if os.path.normcase(p) == os.path.normcase(raiz):
                break
            pai = os.path.dirname(p)
            if pai == p:
                break
            p = pai

        if time.time() - ultimo_aviso > 0.3:
            fila.put(("progresso", (contador, pasta)))
            ultimo_aviso = time.time()

    arquivos.sort(reverse=True)
    pastas = sorted(
        ((t, p) for p, t in tamanho_pastas.items()
         if os.path.normcase(p) != os.path.normcase(raiz)),
        reverse=True,
    )
    fila.put(("fim", (arquivos[:MAX_ARQUIVOS], pastas[:MAX_PASTAS], contador)))


class App(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title("Limpador de Disco - arquivos e pastas grandes")
        self.geometry("1000x620")
        self.minsize(760, 450)

        self.fila = queue.Queue()
        self.cancelar = threading.Event()
        self.tamanhos = {}  # id da linha -> tamanho em bytes
        self.escaneando = False

        self._montar_topo()
        self._montar_abas()
        self._montar_rodape()

    # ---------- interface ----------
    def _montar_topo(self):
        topo = ttk.Frame(self, padding=8)
        topo.pack(fill="x")

        ttk.Label(topo, text="Pasta / disco:").pack(side="left")
        padrao = "C:\\" if sys.platform == "win32" else os.path.expanduser("~")
        self.var_pasta = tk.StringVar(value=padrao)
        ttk.Entry(topo, textvariable=self.var_pasta, width=50).pack(side="left", padx=4, fill="x", expand=True)
        ttk.Button(topo, text="Procurar...", command=self._escolher_pasta).pack(side="left")

        ttk.Label(topo, text="  Arquivos a partir de (MB):").pack(side="left")
        self.var_min = tk.StringVar(value="100")
        ttk.Spinbox(topo, from_=0, to=100000, increment=50, textvariable=self.var_min, width=7).pack(side="left", padx=4)

        self.btn_escanear = ttk.Button(topo, text="Escanear", command=self._iniciar_escaneamento)
        self.btn_escanear.pack(side="left", padx=4)

        self.var_status = tk.StringVar(value="Escolha uma pasta ou disco e clique em Escanear.")
        ttk.Label(self, textvariable=self.var_status, padding=(8, 0)).pack(fill="x")
        self.barra = ttk.Progressbar(self, mode="indeterminate")
        self.barra.pack(fill="x", padx=8, pady=4)

    def _criar_tabela(self, pai):
        frame = ttk.Frame(pai)
        colunas = ("sel", "tamanho", "caminho", "modificado")
        tv = ttk.Treeview(frame, columns=colunas, show="headings", selectmode="extended")
        tv.heading("sel", text="✓")
        tv.heading("tamanho", text="Tamanho")
        tv.heading("caminho", text="Caminho")
        tv.heading("modificado", text="Modificado em")
        tv.column("sel", width=36, anchor="center", stretch=False)
        tv.column("tamanho", width=100, anchor="e", stretch=False)
        tv.column("caminho", width=650)
        tv.column("modificado", width=140, anchor="center", stretch=False)
        sb = ttk.Scrollbar(frame, orient="vertical", command=tv.yview)
        tv.configure(yscrollcommand=sb.set)
        tv.pack(side="left", fill="both", expand=True)
        sb.pack(side="right", fill="y")
        tv.bind("<Button-1>", self._clique)
        tv.bind("<space>", lambda e: self._alternar(tv, tv.selection()))
        tv.bind("<Double-1>", lambda e: self._abrir_local())
        return frame, tv

    def _montar_abas(self):
        self.abas = ttk.Notebook(self)
        self.abas.pack(fill="both", expand=True, padx=8)
        f1, self.tv_arquivos = self._criar_tabela(self.abas)
        f2, self.tv_pastas = self._criar_tabela(self.abas)
        self.abas.add(f1, text="Arquivos grandes")
        self.abas.add(f2, text="Pastas grandes")
        self.abas.bind("<<NotebookTabChanged>>", lambda e: self._atualizar_total())

    def _montar_rodape(self):
        rod = ttk.Frame(self, padding=8)
        rod.pack(fill="x")
        ttk.Button(rod, text="Selecionar tudo", command=lambda: self._marcar_todos(True)).pack(side="left")
        ttk.Button(rod, text="Desmarcar tudo", command=lambda: self._marcar_todos(False)).pack(side="left", padx=4)
        ttk.Button(rod, text="Abrir local", command=self._abrir_local).pack(side="left")
        self.var_total = tk.StringVar(value="Nenhum item marcado")
        ttk.Label(rod, textvariable=self.var_total, padding=(12, 0)).pack(side="left")
        ttk.Button(rod, text="🗑  Mover marcados para a Lixeira", command=self._mover_para_lixeira).pack(side="right")

    # ---------- marcação ----------
    def _tabela_atual(self):
        return self.tv_arquivos if self.abas.index("current") == 0 else self.tv_pastas

    def _clique(self, evento):
        tv = evento.widget
        if tv.identify_region(evento.x, evento.y) == "cell" and tv.identify_column(evento.x) == "#1":
            linha = tv.identify_row(evento.y)
            if linha:
                self._alternar(tv, [linha])
                return "break"

    def _alternar(self, tv, linhas):
        for linha in linhas:
            atual = tv.set(linha, "sel")
            tv.set(linha, "sel", DESMARCADO if atual == MARCADO else MARCADO)
        self._atualizar_total()

    def _marcar_todos(self, marcar):
        tv = self._tabela_atual()
        for linha in tv.get_children():
            tv.set(linha, "sel", MARCADO if marcar else DESMARCADO)
        self._atualizar_total()

    def _marcados(self, tv):
        return [l for l in tv.get_children() if tv.set(l, "sel") == MARCADO]

    def _atualizar_total(self):
        tv = self._tabela_atual()
        marcados = self._marcados(tv)
        if not marcados:
            self.var_total.set("Nenhum item marcado")
        else:
            total = sum(self.tamanhos.get(l, 0) for l in marcados)
            self.var_total.set(f"{len(marcados)} marcado(s) — {formatar_tamanho(total)} a liberar")

    # ---------- escaneamento ----------
    def _escolher_pasta(self):
        pasta = filedialog.askdirectory(initialdir=self.var_pasta.get() or None)
        if pasta:
            self.var_pasta.set(os.path.normpath(pasta))

    def _iniciar_escaneamento(self):
        if self.escaneando:
            self.cancelar.set()
            return
        raiz = os.path.normpath(self.var_pasta.get().strip())
        if not os.path.isdir(raiz):
            messagebox.showerror("Pasta inválida", f"A pasta não existe:\n{raiz}")
            return
        try:
            minimo = float(self.var_min.get().replace(",", ".")) * 1024 * 1024
        except ValueError:
            messagebox.showerror("Valor inválido", "Informe o tamanho mínimo em MB (ex.: 100).")
            return

        for tv in (self.tv_arquivos, self.tv_pastas):
            tv.delete(*tv.get_children())
        self.tamanhos.clear()
        self._atualizar_total()

        self.escaneando = True
        self.cancelar.clear()
        self.btn_escanear.config(text="Cancelar")
        self.barra.start(12)
        self.var_status.set("Escaneando... isso pode levar alguns minutos em discos grandes.")
        threading.Thread(target=escanear, args=(raiz, minimo, self.fila, self.cancelar), daemon=True).start()
        self.after(100, self._verificar_fila)

    def _verificar_fila(self):
        try:
            while True:
                tipo, dados = self.fila.get_nowait()
                if tipo == "progresso":
                    contador, pasta = dados
                    self.var_status.set(f"Escaneando... {contador:,} arquivos lidos — {pasta}".replace(",", "."))
                elif tipo in ("fim", "cancelado"):
                    self._terminar(tipo, dados)
                    return
        except queue.Empty:
            pass
        self.after(100, self._verificar_fila)

    def _terminar(self, tipo, dados):
        self.escaneando = False
        self.barra.stop()
        self.btn_escanear.config(text="Escanear")
        if tipo == "cancelado":
            self.var_status.set("Escaneamento cancelado.")
            return
        arquivos, pastas, contador = dados
        for tamanho, caminho, mtime in arquivos:
            linha = self.tv_arquivos.insert("", "end", values=(
                DESMARCADO, formatar_tamanho(tamanho), caminho,
                time.strftime("%d/%m/%Y %H:%M", time.localtime(mtime))))
            self.tamanhos[linha] = tamanho
        for tamanho, caminho in pastas:
            linha = self.tv_pastas.insert("", "end", values=(DESMARCADO, formatar_tamanho(tamanho), caminho, ""))
            self.tamanhos[linha] = tamanho
        self.var_status.set(
            f"Pronto! {contador:,} arquivos analisados. ".replace(",", ".")
            + f"Mostrando {len(arquivos)} arquivos e {len(pastas)} pastas maiores. "
            "Clique na caixinha ☐ (ou selecione e aperte Espaço) para marcar.")

    # ---------- ações ----------
    def _abrir_local(self):
        tv = self._tabela_atual()
        sel = tv.selection()
        if not sel:
            messagebox.showinfo("Abrir local", "Selecione uma linha primeiro.")
            return
        caminho = tv.set(sel[0], "caminho")
        try:
            if sys.platform == "win32":
                subprocess.Popen(["explorer", "/select,", caminho])
            elif sys.platform == "darwin":
                subprocess.Popen(["open", "-R", caminho])
            else:
                subprocess.Popen(["xdg-open", os.path.dirname(caminho)])
        except OSError as e:
            messagebox.showerror("Erro", str(e))

    def _mover_para_lixeira(self):
        if send2trash is None:
            messagebox.showerror(
                "Falta um componente",
                "Para enviar para a Lixeira é preciso instalar o send2trash.\n\n"
                "Abra o Prompt de Comando e digite:\n    pip install send2trash")
            return
        tv = self._tabela_atual()
        marcados = self._marcados(tv)
        if not marcados:
            messagebox.showinfo("Nada marcado", "Marque os itens clicando na caixinha ☐ da primeira coluna.")
            return
        total = sum(self.tamanhos.get(l, 0) for l in marcados)
        lista = "\n".join(tv.set(l, "caminho") for l in marcados[:10])
        if len(marcados) > 10:
            lista += f"\n... e mais {len(marcados) - 10}"
        if not messagebox.askyesno(
                "Confirmar",
                f"Mover {len(marcados)} item(ns) ({formatar_tamanho(total)}) para a Lixeira?\n\n{lista}\n\n"
                "Lembre-se de esvaziar a Lixeira depois para liberar o espaço."):
            return

        erros, removidos = [], []
        self.config(cursor="watch")
        self.update()
        for linha in marcados:
            caminho = tv.set(linha, "caminho")
            try:
                send2trash(caminho)
                removidos.append(caminho)
            except Exception as e:  # noqa: BLE001 - mostra qualquer falha ao usuário
                erros.append(f"{caminho}: {e}")
        self.config(cursor="")

        self._remover_das_tabelas(removidos)
        self._atualizar_total()
        msg = f"{len(removidos)} item(ns) enviados para a Lixeira."
        if erros:
            msg += f"\n\n{len(erros)} não puderam ser movidos:\n" + "\n".join(erros[:8])
            messagebox.showwarning("Concluído com avisos", msg)
        else:
            messagebox.showinfo("Concluído", msg)

    def _remover_das_tabelas(self, removidos):
        # Tira da lista o item apagado e tudo que estava dentro dele.
        prefixos = [os.path.normcase(p) for p in removidos]
        for tv in (self.tv_arquivos, self.tv_pastas):
            for linha in tv.get_children():
                c = os.path.normcase(tv.set(linha, "caminho"))
                if any(c == p or c.startswith(p + os.sep) for p in prefixos):
                    tv.delete(linha)
                    self.tamanhos.pop(linha, None)


if __name__ == "__main__":
    if sys.platform == "win32":
        try:  # deixa a janela nítida em telas de alta resolução
            import ctypes
            ctypes.windll.shcore.SetProcessDpiAwareness(1)
        except Exception:
            pass
    App().mainloop()
