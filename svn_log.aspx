<%@ Page language="C#"%>
<!--
Copyright 2002-2008 Corey Trager
Distributed under the terms of the GNU General Public License
-->
<%@ Import Namespace="System.Xml" %>
<!-- #include file = "inc.aspx" -->
<script language="C#" runat="server">

DbUtil dbutil;
Security security;

string file_path;
int rev;
string log;

string repository_url = "";
string svn_username = "";
string svn_password = "";
string websvn_url = "";

string string_bugid;

///////////////////////////////////////////////////////////////////////
void Page_Load(Object sender, EventArgs e)
{
	Util.do_not_cache(Response);
	dbutil = new DbUtil();
	security = new Security();
	security.check_security(dbutil, HttpContext.Current, Security.ANY_USER_OK);


	// get info about revision

	string sql = @"
	select svnrev_revision, svnap_path, svnrev_bug
	from svn_revisions
	inner join svn_affected_paths on svnap_svnrev_id = svnrev_id
	where svnap_id = $id
	order by svnrev_revision desc, svnap_path";

	int svnap_id = Convert.ToInt32(Util.sanitize_integer(Request["id"]));
	sql = sql.Replace("$id", Convert.ToString(svnap_id));

	DataRow dr = dbutil.get_datarow(sql);

	// check if user has permission for this bug
	int permission_level = Bug.get_bug_permission_level((int) dr["svnrev_bug"], security);
	if (permission_level == Security.PERMISSION_NONE) {
		Response.Write("You are not allowed to view this item");
		Response.End();
	}

	btnet.Util.get_subversion_connection_info(dbutil,
		(int) dr["svnrev_bug"],
		ref repository_url,
		ref svn_username,
		ref svn_password,
		ref websvn_url);

	file_path = (string) dr["svnap_path"];
    rev = (int)dr["svnrev_revision"];
    string_bugid = Convert.ToString(dr["svnrev_bug"]);
    hidden_bugid.Value = string_bugid;


	log = svn_log(file_path, rev);

	if (log.StartsWith("ERROR:"))
	{
		Response.Write (log);
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
string svn_log(string file_path, int rev)
{
	StringBuilder args = new StringBuilder();

	args.Append("log ");
	args.Append(repository_url);
	args.Append(file_path.Replace(" ", "%20"));
    args.Append("@" + Convert.ToString(rev)); // peg to revision rev in case file deleted
    args.Append(" -r ");
    args.Append(Convert.ToString(rev)); // view log from beginning to rev
	args.Append(":0 --xml -v");

	return run_svn(args.ToString());
}


///////////////////////////////////////////////////////////////////////
void fetch_and_write_history(string file_path)
{

    XmlDocument doc = new XmlDocument();
    doc.LoadXml(log);
    XmlNode log_node = doc.ChildNodes[1];
    string file_path_with_leading_slash = "/" + file_path;
    foreach (XmlElement logentry in log_node)
    {

        string revision = logentry.GetAttribute("revision");
        string author = "";
        string date = "";
        string path = "";
        string action = "";
        //string copy_from = "";
        //string copy_from_rev = "";
        string msg = "";

        foreach (XmlNode node in logentry.ChildNodes)
        {
            if (node.Name == "author") author = node.InnerText;
            else if (node.Name == "date") date = btnet.Util.format_db_date_and_time(XmlConvert.ToDateTime(node.InnerText, XmlDateTimeSerializationMode.Local));
            else if (node.Name == "msg") msg = node.InnerText;
            else if (node.Name == "paths")
            {
                foreach (XmlNode path_node in node.ChildNodes)
                {
                    if (path_node.InnerText == file_path_with_leading_slash)
                    {
                        XmlElement path_el = (XmlElement)path_node;
                        action = path_el.GetAttribute("action");
                        if (!action.Contains("D"))
                        {
                            path = path_node.InnerText;

                            if (path_el.GetAttribute("copyfrom-path") != "")
                            {
                                file_path_with_leading_slash = path_el.GetAttribute("copyfrom-path");
                            }
                        }
                    }
                }
            }
        }

        Response.Write("<tr><td class=datad>" + revision);
        Response.Write("<td class=datad>" + author);
        Response.Write("<td class=datad>" + date);
        Response.Write("<td class=datad>" + path);
        Response.Write("<td class=datad>" + action);
//        Response.Write("<td class=datad>" + copy_from);
//        Response.Write("<td class=datad>" + copy_from_rev);
        Response.Write("<td class=datad>" + msg.Replace(Environment.NewLine, "<br/>"));

        Response.Write("<td class=datad><a target=_blank href=svn_view.aspx?bugid=" + string_bugid + "&rev=" + revision
            + "&path=" + HttpUtility.UrlEncode(path) + ">");
        Response.Write("view</a>");

        Response.Write("<td class=datad><a target=_blank href=svn_blame.aspx?bugid=" + string_bugid + "&rev=" + revision
            + "&path=" + HttpUtility.UrlEncode(path) + ">");
        Response.Write("annotated</a>");

        Response.Write("<td class=datad><a id=r" + revision + " href='javascript:sel_for_diff(" + revision + ")'>select for diff</a>");

    }
}



</script>

<html>
<title>svn log</title>
<link rel="StyleSheet" href="btnet.css" type="text/css">
<script>

function desel_for_diff(rev)
{
	el = document.getElementById("r" + rev)
	el.firstChild.nodeValue = "[select for diff]"
	el.style.fontWeight = ""
	el.style.background = ""

}

function sel_for_diff(rev)
{
	var rev_0 = document.getElementById("rev_0")
	var rev_1 = document.getElementById("rev_1")
	var el = document.getElementById("r" + rev)

	if (el.firstChild.nodeValue == "[SELECTED]")
	{
		desel_for_diff(rev)
		rev_0.value = rev_1.value
		rev_1.value = 0
	}
	else
	{

		if (rev_1.value != 0)
		{
			desel_for_diff(rev_1.value)
		}

		rev_1.value = rev_0.value
		rev_0.value = rev

		el.firstChild.nodeValue = "[SELECTED]"
		el.style.fontWeight = "bold"
		el.style.background = "yellow"

	}

	// enable, disable link
	if (rev_1.value != 0 && rev_0.value != 0 && rev_1.value != rev_0.value)
	{
		document.getElementById("do_diff_enabled").style.display = "block"
		document.getElementById("do_diff_disabled").style.display = "none"
		frm.rev_0.value = rev_0.value
		frm.rev_1.value = rev_1.value

	}
	else
	{
		document.getElementById("do_diff_enabled").style.display = "none"
		document.getElementById("do_diff_disabled").style.display = "block"
	}

}

function on_do_diff()
{
	var rev_0 = document.getElementById("rev_0")
	var rev_1 = document.getElementById("rev_1")

	if (rev_1.value != 0 && rev_0.value != 0 && rev_1.value != rev_0.value)
	{
		frm.submit()
	}
	else
	{
		alert("First select two revisions to diff (compare side-by-side)")
	}

}
</script>
<body>

<p>
<div style="font-size:12pt; font-weight: bold;">
	History (svn log) of path: <% Response.Write(file_path); %>
</div>
<p>

<form id="frm" target=_blank action="svn_diff.aspx" method="GET">

<input type=hidden name="path" value="<% Response.Write(file_path); %>">
<input type=hidden name="rev_0" id="rev_0" value="0"></input>
<input type=hidden name="rev_1" id="rev_1" value="0"></input>
<input type=hidden name="hidden_bugid" id="hidden_bugid" value="0" runat="server"></input>
</form>

<p>

<table border=1 class=datat>
<tr>
<td class=datah>revision
<td class=datah>author
<td class=datah>date
<td class=datah>path
<td class=datah>action<br>
<td class=datah>msg
<td class=datah>view
<td class=datah>view<br>annotated<br>(svn blame)
<td class=datah>
<span></span><a
style="display: none; background: yellow;
border-top: 1px silver solid;
border-left: 1px silver solid;
border-bottom: 2px black solid;
border-right: 2px black solid;
"
id="do_diff_enabled" href="javascript:on_do_diff()">click<br>to<br>diff</a>
<a style="color: red;"   id="do_diff_disabled" href="javascript:on_do_diff()">select<br>two<br>revisions</a></span>
<% fetch_and_write_history(file_path); %>

</table>

</body>

</html>
