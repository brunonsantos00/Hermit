// Executável que abre o painel do Backup e Migração (windows\painel.ps1).
// Compile com launcher\compilar.ps1. O .exe precisa ficar na raiz do projeto,
// ao lado das pastas "windows" e "linux".

using System;
using System.Diagnostics;
using System.IO;
using System.Reflection;
using System.Windows.Forms;

[assembly: AssemblyTitle("Backup e Migração")]
[assembly: AssemblyProduct("Backup e Migração")]
[assembly: AssemblyDescription("Backup e migração de computadores Windows e Linux")]
[assembly: AssemblyVersion("2.0.0.0")]
[assembly: AssemblyFileVersion("2.0.0.0")]

static class Programa
{
    const string Titulo = "Backup e Migração";

    [STAThread]
    static void Main()
    {
        string pasta = AppDomain.CurrentDomain.BaseDirectory;
        string painel = Path.Combine(pasta, "windows", "painel.ps1");

        if (!File.Exists(painel))
        {
            MessageBox.Show(
                "Não encontrei o arquivo:\n" + painel + "\n\n" +
                "Deixe este programa na mesma pasta que as pastas \"windows\" e \"linux\".",
                Titulo, MessageBoxButtons.OK, MessageBoxIcon.Error);
            return;
        }

        var inicio = new ProcessStartInfo
        {
            FileName = "powershell.exe",
            Arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File \"" + painel + "\"",
            WorkingDirectory = Path.GetDirectoryName(painel),
            UseShellExecute = false,
            CreateNoWindow = true
        };

        try
        {
            Process.Start(inicio);
        }
        catch (Exception erro)
        {
            MessageBox.Show("Não foi possível abrir o painel:\n" + erro.Message,
                            Titulo, MessageBoxButtons.OK, MessageBoxIcon.Error);
        }
    }
}
