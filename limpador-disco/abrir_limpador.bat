@echo off
cd /d "%~dp0"
python -m pip install --quiet send2trash
start "" pythonw limpador_disco.py
