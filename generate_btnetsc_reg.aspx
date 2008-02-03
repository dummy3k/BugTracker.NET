%@ Page language="C#"%>
<!-- #include file = "inc.aspx" -->
<script language="C#" runat="server">

//Copyright 2002-2008 Corey Trager
//Distributed under the terms of the GNU General Public License
// Updated to support new 1.8+ version of btnetsc -WER

DbUtil dbutil;
Security security;

///////////////////////////////////////////////////////////////////////
void Page_Load(Object sender, EventArgs e)
{

dbutil = new DbUtil();
security = new Security();
security.check_security(dbutil, HttpContext.Current, Security.ANY_USER_OK);

Response.ContentType = "text/reg";
Response.AddHeader ("content-disposition","attachment; filename=\"btnetsc.reg\"");
Response.Write ("Windows Registry Editor Version 5.00");
Response.Write ("\n\n");
Response.Write ("[HKEY_CURRENT_USER\\Software\\BugTracker.NET\\btnetsc\\SETTINGS]" + "\n");

string url = "http://" + Request.ServerVariables["SERVER_NAME"] + Request.ServerVariables["URL"];
url = url.Replace("generate_btnetsc_reg","insert_bug");
write_variable_value("Url", url);
write_variable_value("Project", "0");
write_variable_value("Email", security.user.email);
write_variable_value("Username", security.user.username);


NameValueCollection NVCSrvElements = Request.ServerVariables;
string[] array1 = NVCSrvElements.AllKeys;

for (int i = 0; i < array1.Length; i++){
Response.Write(array1[i]);
Response.Write("=");
Response.Write(Request.ServerVariables[array1[i]]);
Response.Write("<br>");
}

}

void write_variable_value(string var, string val)
{
Response.Write ("\"" + var + "\"=\"" + val + "\"\n");
}



</script>

