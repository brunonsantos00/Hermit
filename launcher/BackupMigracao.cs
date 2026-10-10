// Executável que abre o painel do Backup e Migração (windows\painel.ps1).
// Compile com launcher\compilar.ps1. O .exe precisa ficar na raiz do projeto,
// ao lado das pastas "windows" e "linux".

using System;
using System.Diagnostics;
using System.Globalization;
using System.IO;
using System.Reflection;
using System.Windows.Forms;

[assembly: AssemblyTitle("Backup e Migração")]
[assembly: AssemblyProduct("Backup e Migração")]
[assembly: AssemblyDescription("Backup e migração de computadores Windows e Linux")]
[assembly: AssemblyVersion("2.1.0.0")]
[assembly: AssemblyFileVersion("2.1.0.0")]

static class Programa
{
    static bool ingles;

    // Mesmo critério do painel: escolha salva no painel, senão o idioma do Windows
    static bool UsarIngles()
    {
        try
        {
            string salvo = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                                        "BackupMigracao", "idioma.txt");
            if (File.Exists(salvo))
            {
                string v = File.ReadAllText(salvo).Trim();
                if (v == "pt") return false;
                if (v == "en") return true;
            }
        }
        catch { }
        return !CultureInfo.CurrentUICulture.Name.StartsWith("pt");
    }

    static string L(string pt, string en) { return ingles ? en : pt; }

    [STAThread]
    static void Main()
    {
        ingles = UsarIngles();
        string titulo = L("Backup e Migração", "Backup and Migration");
        string pasta = AppDomain.CurrentDomain.BaseDirectory;
        string painel = Path.Combine(pasta, "windows", "painel.ps1");

        if (!File.Exists(painel))
        {
            MessageBox.Show(
                L("Não encontrei o arquivo:\n", "File not found:\n") + painel + "\n\n" +
                L("Deixe este programa na mesma pasta que as pastas \"windows\" e \"linux\".",
                  "Keep this program in the same folder as the \"windows\" and \"linux\" folders."),
                titulo, MessageBoxButtons.OK, MessageBoxIcon.Error);
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
            MessageBox.Show(L("Não foi possível abrir o painel:\n", "Could not open the panel:\n") + erro.Message,
                            titulo, MessageBoxButtons.OK, MessageBoxIcon.Error);
        }
    }
}
