@echo off
:: Run DNS Manager with Administrator privileges
PowerShell -Command "Start-Process PowerShell -ArgumentList '-ExecutionPolicy Bypass -File \"%~dp0DNS-Manager.ps1\"' -Verb RunAs"
