# Limpador de Disco

Programa simples que encontra **arquivos e pastas grandes** no HD e permite
marcá-los e **enviá-los para a Lixeira** (nada é apagado definitivamente).

**Não precisa instalar nada**: é um único arquivo, `LimpadorDisco.bat`, que usa o
PowerShell que já vem no Windows 10/11.

## Como usar

1. Baixe o arquivo `LimpadorDisco.bat` e dê dois cliques nele.
   - Se aparecer "O Windows protegeu o computador", clique em **Mais informações → Executar assim mesmo**.
2. Escolha a pasta ou disco (ex.: `C:\`), o tamanho mínimo dos arquivos em MB e clique em **Escanear**.
   Em um disco inteiro isso pode levar alguns minutos.
3. Nas abas **Arquivos grandes** / **Pastas grandes**, marque as caixinhas dos itens que quer apagar
   (ou use **Selecionar tudo** / **Desmarcar tudo**).
4. Clique em **Mover marcados para a Lixeira** e confirme.
5. **Esvazie a Lixeira** para o espaço ser realmente liberado.

Dica: selecione uma linha e clique em **Abrir local** para ver o arquivo no Explorer antes de apagar.

> ⚠️ Cuidado com pastas do sistema (`C:\Windows`, `Program Files`, `pagefile.sys`, `hiberfil.sys`).
> Apague apenas o que você reconhece: downloads antigos, vídeos, instaladores, backups etc.
