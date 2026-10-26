<# :
@echo off
rem Limpador de Disco - de dois cliques neste arquivo para abrir.
rem Nao precisa instalar nada: usa o PowerShell que ja vem no Windows.
set "LIMPADOR_ARQ=%~f0"
echo Abrindo o Limpador de Disco... (pode minimizar esta janela, mas nao feche)
powershell -NoProfile -ExecutionPolicy Bypass -STA -Command "iex ([IO.File]::ReadAllText($env:LIMPADOR_ARQ, [Text.Encoding]::UTF8))"
if errorlevel 1 pause
exit /b
#>

# ===================== Limpador de Disco (PowerShell) =====================
Add-Type -AssemblyName System.Windows.Forms, System.Drawing, Microsoft.VisualBasic
[System.Windows.Forms.Application]::EnableVisualStyles()

$MaxArquivos = 500
$MaxPastas = 300
$script:cancelar = $false
$script:escaneando = $false
$script:emLote = $false

function Format-Tamanho([double]$n) {
    $u = 'B', 'KB', 'MB', 'GB', 'TB'
    $i = 0
    while ($n -ge 1024 -and $i -lt 4) { $n /= 1024; $i++ }
    if ($i -eq 0) { '{0:N0} {1}' -f $n, $u[$i] } else { '{0:N1} {1}' -f $n, $u[$i] }
}

# ---------- janela ----------
$form = New-Object System.Windows.Forms.Form
$form.Text = 'Limpador de Disco - arquivos e pastas grandes'
$form.ClientSize = New-Object System.Drawing.Size(1060, 640)
$form.MinimumSize = New-Object System.Drawing.Size(800, 450)
$form.StartPosition = 'CenterScreen'
$form.Font = New-Object System.Drawing.Font('Segoe UI', 9)

function Novo($tipo, $x, $y, $w, $h, $texto, $ancora) {
    $c = New-Object "System.Windows.Forms.$tipo"
    $c.Location = New-Object System.Drawing.Point($x, $y)
    if ($w) { $c.Size = New-Object System.Drawing.Size($w, $h) }
    if ($texto) { $c.Text = $texto }
    if ($ancora) { $c.Anchor = $ancora }
    $form.Controls.Add($c)
    $c
}

$lblPasta    = Novo Label 10 14 88 20 'Pasta / disco:' 'Top,Left'
$txtPasta    = Novo TextBox 100 10 480 24 'C:\' 'Top,Left,Right'
$btnProcurar = Novo Button 590 8 85 27 'Procurar...' 'Top,Right'
$lblMin      = Novo Label 685 14 160 20 'Arquivos a partir de (MB):' 'Top,Right'
$numMin      = Novo NumericUpDown 850 10 70 24 $null 'Top,Right'
$numMin.Maximum = 1000000; $numMin.Increment = 50; $numMin.Value = 100
$btnEscanear = Novo Button 930 8 120 27 'Escanear' 'Top,Right'

$lblStatus = Novo Label 10 42 1040 20 'Escolha uma pasta ou disco e clique em Escanear.' 'Top,Left,Right'
$lblStatus.AutoEllipsis = $true
$barra = Novo ProgressBar 10 64 1040 12 $null 'Top,Left,Right'
$barra.Style = 'Marquee'; $barra.Visible = $false

$abas = Novo TabControl 10 84 1040 500 $null 'Top,Bottom,Left,Right'

function Nova-Lista($titulo) {
    $pag = New-Object System.Windows.Forms.TabPage
    $pag.Text = $titulo
    $lv = New-Object System.Windows.Forms.ListView
    $lv.View = 'Details'; $lv.CheckBoxes = $true; $lv.FullRowSelect = $true
    $lv.HideSelection = $false; $lv.Dock = 'Fill'; $lv.GridLines = $true
    [void]$lv.Columns.Add('Tamanho', 110)
    [void]$lv.Columns.Add('Caminho', 740)
    [void]$lv.Columns.Add('Modificado em', 140)
    $lv.Add_ItemChecked({ if (-not $script:emLote) { Atualizar-Total } })
    $pag.Controls.Add($lv)
    $abas.TabPages.Add($pag)
    $lv
}
$lvArquivos = Nova-Lista 'Arquivos grandes'
$lvPastas   = Nova-Lista 'Pastas grandes'

$btnTodos   = Novo Button 10 595 115 30 'Selecionar tudo' 'Bottom,Left'
$btnNenhum  = Novo Button 130 595 115 30 'Desmarcar tudo' 'Bottom,Left'
$btnAbrir   = Novo Button 250 595 115 30 'Abrir local' 'Bottom,Left'
$lblTotal   = Novo Label 380 602 440 20 'Nenhum item marcado' 'Bottom,Left,Right'
$btnLixeira = Novo Button 830 592 220 36 'Mover marcados para a Lixeira' 'Bottom,Right'
$btnLixeira.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)

# ---------- funções ----------
function Lista-Atual { if ($abas.SelectedIndex -eq 0) { $lvArquivos } else { $lvPastas } }

function Atualizar-Total {
    $lv = Lista-Atual
    $n = $lv.CheckedItems.Count
    if ($n -eq 0) { $lblTotal.Text = 'Nenhum item marcado'; return }
    [long]$t = 0
    foreach ($it in $lv.CheckedItems) { $t += $it.Tag.Tamanho }
    $lblTotal.Text = "$n marcado(s) - $(Format-Tamanho $t) a liberar"
}

function Marcar-Todos([bool]$valor) {
    $lv = Lista-Atual
    $script:emLote = $true
    $lv.BeginUpdate()
    foreach ($it in $lv.Items) { $it.Checked = $valor }
    $lv.EndUpdate()
    $script:emLote = $false
    Atualizar-Total
}

function Escanear([string]$raiz, [long]$minimo) {
    $arquivos = New-Object System.Collections.Generic.List[object]
    $pastas = @{}
    $pilha = New-Object System.Collections.Generic.Stack[string]
    $pilha.Push($raiz)
    $raizNorm = $raiz.TrimEnd('\')
    $cont = 0
    $relogio = [Diagnostics.Stopwatch]::StartNew()
    # Pastas da nuvem (OneDrive) são "reparse points", mas não são atalhos: essas devem ser lidas.
    $bitsNuvem = 0x80000 -bor 0x100000 -bor 0x400000 -bor 0x40000

    while ($pilha.Count -gt 0) {
        if ($script:cancelar) { return $null }
        $pasta = $pilha.Pop()
        [long]$total = 0
        try {
            $di = New-Object System.IO.DirectoryInfo $pasta
            foreach ($e in $di.EnumerateFileSystemInfos()) {
                $attr = [int]$e.Attributes
                if ($attr -band 16) {
                    # Ignora atalhos de pasta (junções/links) para não contar nada duas vezes.
                    if (($attr -band 1024) -and -not ($attr -band $bitsNuvem)) { continue }
                    $pilha.Push($e.FullName)
                } else {
                    if ($attr -band 0x400000) { continue }  # arquivo só na nuvem: não ocupa espaço local
                    $len = $e.Length
                    $total += $len
                    $cont++
                    if ($len -ge $minimo) {
                        $arquivos.Add([pscustomobject]@{ Tamanho = $len; Caminho = $e.FullName; Data = $e.LastWriteTime })
                    }
                }
            }
        } catch { }

        # Soma o tamanho desta pasta em todas as pastas acima dela, até a raiz.
        $p = $pasta
        while ($true) {
            $pastas[$p] = [long]$pastas[$p] + $total
            if ($p.TrimEnd('\') -eq $raizNorm) { break }
            $pai = [IO.Path]::GetDirectoryName($p)
            if (-not $pai) { break }
            $p = $pai
        }

        if ($relogio.ElapsedMilliseconds -gt 250) {
            $lblStatus.Text = "Escaneando... $($cont.ToString('N0')) arquivos lidos - $pasta"
            [System.Windows.Forms.Application]::DoEvents()
            $relogio.Restart()
        }
    }

    $lblStatus.Text = 'Organizando resultados...'
    [System.Windows.Forms.Application]::DoEvents()
    $topArq = @($arquivos | Sort-Object Tamanho -Descending | Select-Object -First $MaxArquivos)
    $topPastas = @($pastas.GetEnumerator() | Where-Object { $_.Key.TrimEnd('\') -ne $raizNorm } |
        Sort-Object Value -Descending | Select-Object -First $MaxPastas)
    return @{ Arquivos = $topArq; Pastas = $topPastas; Contador = $cont }
}

function Adicionar-Item($lv, [long]$tamanho, [string]$caminho, [string]$data) {
    $it = New-Object System.Windows.Forms.ListViewItem (Format-Tamanho $tamanho)
    [void]$it.SubItems.Add($caminho)
    [void]$it.SubItems.Add($data)
    $it.Tag = [pscustomobject]@{ Tamanho = $tamanho; Caminho = $caminho }
    [void]$lv.Items.Add($it)
}

$btnEscanear.Add_Click({
    if ($script:escaneando) { $script:cancelar = $true; return }
    $raiz = $txtPasta.Text.Trim()
    if (-not [IO.Directory]::Exists($raiz)) {
        [System.Windows.Forms.MessageBox]::Show("A pasta não existe:`n$raiz", 'Pasta inválida', 'OK', 'Error') | Out-Null
        return
    }
    $raiz = [IO.Path]::GetFullPath($raiz)
    if ($raiz.Length -gt 3) { $raiz = $raiz.TrimEnd('\') }

    $lvArquivos.Items.Clear(); $lvPastas.Items.Clear(); Atualizar-Total
    $script:escaneando = $true; $script:cancelar = $false
    $btnEscanear.Text = 'Cancelar'; $barra.Visible = $true
    foreach ($b in $btnLixeira, $btnTodos, $btnNenhum, $btnProcurar) { $b.Enabled = $false }
    $lblStatus.Text = 'Escaneando... isso pode levar alguns minutos em discos grandes.'

    try {
        $r = Escanear $raiz ([long]($numMin.Value * 1MB))
    } finally {
        $script:escaneando = $false
        $btnEscanear.Text = 'Escanear'; $barra.Visible = $false
        foreach ($b in $btnLixeira, $btnTodos, $btnNenhum, $btnProcurar) { $b.Enabled = $true }
    }
    if ($null -eq $r) { $lblStatus.Text = 'Escaneamento cancelado.'; return }

    $script:emLote = $true
    $lvArquivos.BeginUpdate()
    foreach ($a in $r.Arquivos) { Adicionar-Item $lvArquivos $a.Tamanho $a.Caminho $a.Data.ToString('dd/MM/yyyy HH:mm') }
    $lvArquivos.EndUpdate()
    $lvPastas.BeginUpdate()
    foreach ($p in $r.Pastas) { Adicionar-Item $lvPastas $p.Value $p.Key '' }
    $lvPastas.EndUpdate()
    $script:emLote = $false

    $lblStatus.Text = "Pronto! $($r.Contador.ToString('N0')) arquivos analisados. " +
        "Mostrando $($r.Arquivos.Count) arquivos e $($r.Pastas.Count) pastas maiores. Marque as caixinhas para escolher."
})

$btnProcurar.Add_Click({
    $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
    $dlg.Description = 'Escolha a pasta ou disco para escanear'
    if ([IO.Directory]::Exists($txtPasta.Text)) { $dlg.SelectedPath = $txtPasta.Text }
    if ($dlg.ShowDialog($form) -eq 'OK') { $txtPasta.Text = $dlg.SelectedPath }
})

$btnTodos.Add_Click({ Marcar-Todos $true })
$btnNenhum.Add_Click({ Marcar-Todos $false })
$abas.Add_SelectedIndexChanged({ Atualizar-Total })

$btnAbrir.Add_Click({
    $lv = Lista-Atual
    if ($lv.SelectedItems.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show('Clique numa linha primeiro.', 'Abrir local') | Out-Null
        return
    }
    $c = $lv.SelectedItems[0].Tag.Caminho
    Start-Process explorer.exe "/select,`"$c`""
})

$btnLixeira.Add_Click({
    $lv = Lista-Atual
    $marcados = @($lv.CheckedItems | ForEach-Object { $_ })
    if ($marcados.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show('Marque os itens clicando na caixinha ao lado do tamanho.', 'Nada marcado') | Out-Null
        return
    }
    [long]$t = 0
    foreach ($it in $marcados) { $t += $it.Tag.Tamanho }
    $lista = ($marcados | Select-Object -First 10 | ForEach-Object { $_.Tag.Caminho }) -join "`n"
    if ($marcados.Count -gt 10) { $lista += "`n... e mais $($marcados.Count - 10)" }
    $resp = [System.Windows.Forms.MessageBox]::Show(
        "Mover $($marcados.Count) item(ns) ($(Format-Tamanho $t)) para a Lixeira?`n`n$lista`n`nLembre-se de esvaziar a Lixeira depois para liberar o espaço.",
        'Confirmar', 'YesNo', 'Question')
    if ($resp -ne 'Yes') { return }

    $removidos = New-Object System.Collections.Generic.List[string]
    $erros = New-Object System.Collections.Generic.List[string]
    $form.Cursor = 'WaitCursor'
    foreach ($it in $marcados) {
        $c = $it.Tag.Caminho
        try {
            # AllDialogs: se o item for grande demais para a Lixeira, o próprio Windows avisa antes.
            if ([IO.Directory]::Exists($c)) {
                [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteDirectory($c, 'AllDialogs', 'SendToRecycleBin')
            } else {
                [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile($c, 'AllDialogs', 'SendToRecycleBin')
            }
            $removidos.Add($c)
        } catch {
            $ex = $_.Exception
            if ($ex.InnerException) { $ex = $ex.InnerException }
            if ($ex -is [System.OperationCanceledException]) { $erros.Add("$c : cancelado") }
            else { $erros.Add("$c : $($ex.Message)") }
        }
    }
    $form.Cursor = 'Default'

    # Tira das listas o item apagado e tudo que estava dentro dele.
    foreach ($l in $lvArquivos, $lvPastas) {
        $l.BeginUpdate()
        for ($i = $l.Items.Count - 1; $i -ge 0; $i--) {
            $c = $l.Items[$i].Tag.Caminho
            foreach ($r in $removidos) {
                if ($c -eq $r -or $c.StartsWith($r.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) {
                    $l.Items.RemoveAt($i); break
                }
            }
        }
        $l.EndUpdate()
    }
    Atualizar-Total

    $msg = "$($removidos.Count) item(ns) enviados para a Lixeira."
    if ($erros.Count -gt 0) {
        $msg += "`n`n$($erros.Count) não puderam ser movidos:`n" + (($erros | Select-Object -First 8) -join "`n")
        [System.Windows.Forms.MessageBox]::Show($msg, 'Concluído com avisos', 'OK', 'Warning') | Out-Null
    } else {
        [System.Windows.Forms.MessageBox]::Show($msg, 'Concluído', 'OK', 'Information') | Out-Null
    }
})

$form.Add_FormClosing({ $script:cancelar = $true })
[void]$form.ShowDialog()
