// Executable that opens the Hermit panel (windows\panel.ps1).
//
// Two modes, same code:
//  - Normal:   the .exe sits at the project root, next to the "windows" and "linux" folders.
//  - Portable: the project is embedded in the .exe ("hermit.zip" resource). On first run it is
//              extracted to %LOCALAPPDATA%\Hermit\<version> and the panel is opened from there.
// Build with launcher\build.ps1 (normal) or launcher\build-release.ps1 (portable + .zip).
// With /define:COMPARADOR the same code builds Hermit-Compare.exe, which opens windows\compare-window.ps1.

using System;
using System.Diagnostics;
using System.Globalization;
using System.IO;
using System.IO.Compression;
using System.Reflection;
using System.Windows.Forms;

#if COMPARADOR
[assembly: AssemblyTitle("Hermit - Comparador de backup")]
#else
[assembly: AssemblyTitle("Hermit - Backup e Migração")]
#endif
[assembly: AssemblyProduct("Hermit")]
[assembly: AssemblyDescription("Backup e migração de computadores Windows e Linux")]
[assembly: AssemblyVersion("2.1.0.0")]
[assembly: AssemblyFileVersion("2.1.0.0")]

static class Programa
{
    const string Versao = "2.1";
#if COMPARADOR
    const string Script = "compare-window.ps1";
#else
    const string Script = "panel.ps1";
#endif
    static bool ingles;

    // Same rule as the panel: the choice saved in the panel, otherwise the Windows language
    static bool UsarIngles()
    {
        try
        {
            string salvo = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                                        "Hermit", "language.txt");
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

    // Portable mode: extracts the embedded project (only the first time for each version)
    static string ExtrairEmbutido()
    {
        using (Stream zip = Assembly.GetExecutingAssembly().GetManifestResourceStream("hermit.zip"))
        {
            if (zip == null) return null;
            string destino = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                                          "Hermit", Versao);
            string painel = Path.Combine(destino, "windows", Script);
            if (File.Exists(painel)) return painel;

            string temporario = destino + ".tmp";
            if (Directory.Exists(temporario)) Directory.Delete(temporario, true);
            Directory.CreateDirectory(temporario);
            using (var arquivo = new ZipArchive(zip, ZipArchiveMode.Read))
            {
                foreach (ZipArchiveEntry item in arquivo.Entries)
                {
                    string caminho = Path.GetFullPath(Path.Combine(temporario, item.FullName));
                    if (!caminho.StartsWith(Path.GetFullPath(temporario), StringComparison.OrdinalIgnoreCase)) continue;
                    if (item.FullName.EndsWith("/")) { Directory.CreateDirectory(caminho); continue; }
                    Directory.CreateDirectory(Path.GetDirectoryName(caminho));
                    item.ExtractToFile(caminho, true);
                }
            }
            if (Directory.Exists(destino)) Directory.Delete(destino, true);
            Directory.Move(temporario, destino);
            return painel;
        }
    }

    [STAThread]
    static void Main()
    {
        ingles = UsarIngles();
        #if COMPARADOR
        string titulo = L("Comparador de backup", "Backup comparison");
#else
        string titulo = L("Backup e Migração", "Backup and Migration");
#endif
        string painel = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "windows", Script);

        if (!File.Exists(painel))
        {
            try { painel = ExtrairEmbutido(); }
            catch (Exception erro)
            {
                MessageBox.Show(L("Não foi possível preparar os arquivos do programa:\n", "Could not prepare the program files:\n") + erro.Message,
                                titulo, MessageBoxButtons.OK, MessageBoxIcon.Error);
                return;
            }
        }

        if (painel == null || !File.Exists(painel))
        {
            MessageBox.Show(
                L("Não encontrei a pasta \"windows\".\n\n", "The \"windows\" folder was not found.\n\n") +
                L("Deixe este programa na mesma pasta que as pastas \"windows\" e \"linux\",\nou baixe a versão portátil (Hermit-v" + Versao + ".exe) na página de Releases.",
                  "Keep this program in the same folder as the \"windows\" and \"linux\" folders,\nor download the portable version (Hermit-v" + Versao + ".exe) from the Releases page."),
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
