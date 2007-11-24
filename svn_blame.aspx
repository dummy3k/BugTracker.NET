<%@ Page language="C#"%>
<%@ Import Namespace="System.Xml" %>
<!-- #include file = "inc.aspx" -->
<script language="C#" runat="server">

//Copyright 2002-2007 Corey Trager
//Distributed under the terms of the GNU General Public License


DbUtil dbutil;
Security security;

string blame;
string text;

string repository_url = "";
string svn_username = "";
string svn_password = "";
string websvn_url = "";

///////////////////////////////////////////////////////////////////////
void Page_Load(Object sender, EventArgs e)
{
	Util.do_not_cache(Response);
	dbutil = new DbUtil();
	security = new Security();
	security.check_security(dbutil, HttpContext.Current, Security.ANY_USER_OK);

	btnet.Util.get_subversion_connection_info(dbutil,
		Convert.ToInt32(Request["bugid"]),
		ref repository_url,
		ref svn_username,
		ref svn_password,
		ref websvn_url);

    text = svn_cat(Request["path"], Convert.ToInt32(Request["rev"]));

	if (text.StartsWith("ERROR:"))
	{
        Response.Write(text);
		Response.End();
	}

    blame = svn_blame(Request["path"], Convert.ToInt32(Request["rev"]));

    if (blame.StartsWith("ERROR:"))
    {
        Response.Write(blame);
        Response.End();
    }

}

///////////////////////////////////////////////////////////////////////
string run_svn(string args)
{
	string output = Util.run_svn(args, svn_username, svn_password);
	if (output.StartsWith("ERROR:"))
	{
		Response.Write(output);
		Response.End();
	}
	return output;
}

///////////////////////////////////////////////////////////////////////
string svn_cat(string file_path, int revision)
{
	StringBuilder args = new StringBuilder();

	args.Append("cat ");

	args.Append(repository_url);
	args.Append(file_path.Replace(" ", "%20"));
	args.Append("@");
	args.Append(Convert.ToString(revision));

	return run_svn(args.ToString());
}

///////////////////////////////////////////////////////////////////////
string svn_blame(string file_path, int revision)
{
	StringBuilder args = new StringBuilder();

	args.Append("blame ");
	args.Append(repository_url);
    args.Append(file_path.Replace(" ", "%20"));
    args.Append("@");
    args.Append(Convert.ToString(revision));
    args.Append(" --xml");

	return run_svn(args.ToString());
}


///////////////////////////////////////////////////////////////////////
void write_blame()
{

    XmlDocument doc = new XmlDocument();
    doc.LoadXml(blame);
    XmlNodeList commits = doc.GetElementsByTagName("commit");

	// split the source text into lines
	Regex regex = new Regex("\r\n");
	string[] lines = regex.Split(text);

    for (int i = 0; i < commits.Count; i++)
    {
        XmlElement commit = (XmlElement)commits[i];
        Response.Write("<tr><td nowrap>" + commit.GetAttribute("revision"));

        string author = "";
        string date = "";

        foreach (XmlNode node in commit.ChildNodes)
        {
            if (node.Name == "author") author = node.InnerText;
            else if (node.Name == "date") date = btnet.Util.format_db_date(XmlConvert.ToDateTime(node.InnerText, XmlDateTimeSerializationMode.Local));
        }

        Response.Write("<td nowrap>" + author);
        Response.Write("<td nowrap style='background: #ddffdd'><pre style='display:inline;'> " + HttpUtility.HtmlEncode(lines[i]));
        Response.Write(" </pre><td nowrap>" + date);

    }

}



</script>

<html>
<title>svn blame</title>
<link rel="StyleSheet" href="btnet.css" type="text/css">
<body>

<p>
<div style="font-size:12pt; font-weight: bold;">
	Annotated view (svn blame) of path: <% Response.Write(Request["path"]); %>, Revision: <% Response.Write(Request["rev"]); %>
</div>
<p>

<p>
<pre>
<table border=0 class=datat cellspacing=0 cellpadding=0>
<tr>
<td class=datah>revision
<td class=datah>author
<td class=datah>text
<td class=datah>date
<% write_blame(); %>
</table>
</pre>






</body>

</html>
