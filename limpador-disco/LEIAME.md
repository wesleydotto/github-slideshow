# Limpador de Disco

Programa simples que encontra **arquivos e pastas grandes** no seu HD e permite
marcá-los e **enviá-los para a Lixeira** (nada é apagado definitivamente).

## Como usar (Windows)

1. Instale o Python em https://www.python.org/downloads/ (marque **"Add Python to PATH"**).
2. Dê dois cliques em `abrir_limpador.bat` (na primeira vez ele instala o `send2trash`).
3. Escolha a pasta ou disco (ex.: `C:\`), o tamanho mínimo dos arquivos em MB e clique em **Escanear**.
4. Nas abas **Arquivos grandes** / **Pastas grandes**, clique na caixinha ☐ para marcar
   (ou selecione várias linhas e aperte **Espaço**). Use **Selecionar tudo** / **Desmarcar tudo** se quiser.
5. Clique em **Mover marcados para a Lixeira** e confirme.
6. **Esvazie a Lixeira** para o espaço ser realmente liberado.

Dica: dê duplo clique numa linha (ou use **Abrir local**) para ver o arquivo no Explorer antes de apagar.

> ⚠️ Cuidado com pastas do sistema (`C:\Windows`, `Program Files`, `pagefile.sys`, `hiberfil.sys`).
> Apague apenas o que você reconhece — downloads antigos, vídeos, instaladores, backups etc.

Também funciona em Linux/macOS: `pip install send2trash` e `python3 limpador_disco.py`.
