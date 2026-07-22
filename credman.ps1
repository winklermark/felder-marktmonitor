# Zugriff auf den Windows Credential Manager (DPAPI) - wird von setup-passwort.ps1 und auto-update.ps1 eingebunden.
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class TrCredMan {
    [DllImport("advapi32", SetLastError = true, EntryPoint = "CredReadW", CharSet = CharSet.Unicode)]
    private static extern bool CredRead(string target, int type, int flags, out IntPtr cred);
    [DllImport("advapi32", SetLastError = true, EntryPoint = "CredWriteW", CharSet = CharSet.Unicode)]
    private static extern bool CredWrite(ref CREDENTIAL cred, int flags);
    [DllImport("advapi32")]
    private static extern void CredFree(IntPtr buffer);
    [DllImport("advapi32", SetLastError = true, EntryPoint = "CredDeleteW", CharSet = CharSet.Unicode)]
    public static extern bool CredDelete(string target, int type, int flags);

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    public struct CREDENTIAL {
        public int Flags;
        public int Type;
        public string TargetName;
        public string Comment;
        public System.Runtime.InteropServices.ComTypes.FILETIME LastWritten;
        public int CredentialBlobSize;
        public IntPtr CredentialBlob;
        public int Persist;
        public int AttributeCount;
        public IntPtr Attributes;
        public string TargetAlias;
        public string UserName;
    }

    public static string Read(string target) {
        IntPtr p;
        if (!CredRead(target, 1, 0, out p)) { return null; }
        try {
            CREDENTIAL c = (CREDENTIAL)Marshal.PtrToStructure(p, typeof(CREDENTIAL));
            if (c.CredentialBlobSize <= 0) { return ""; }
            return Marshal.PtrToStringUni(c.CredentialBlob, c.CredentialBlobSize / 2);
        } finally { CredFree(p); }
    }

    public static bool Write(string target, string secret) {
        byte[] bytes = System.Text.Encoding.Unicode.GetBytes(secret);
        CREDENTIAL c = new CREDENTIAL();
        c.Type = 1;                // CRED_TYPE_GENERIC
        c.TargetName = target;
        c.UserName = "trend-radar";
        c.Persist = 2;             // CRED_PERSIST_LOCAL_MACHINE (nur dieser Windows-Benutzer)
        c.CredentialBlobSize = bytes.Length;
        c.CredentialBlob = Marshal.AllocHGlobal(bytes.Length);
        try {
            Marshal.Copy(bytes, 0, c.CredentialBlob, bytes.Length);
            return CredWrite(ref c, 0);
        } finally { Marshal.FreeHGlobal(c.CredentialBlob); }
    }
}
"@
