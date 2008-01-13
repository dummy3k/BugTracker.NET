<%@ Page language="C#"%>
<%@ Import Namespace="System.Xml" %>
<!-- #include file = "inc.aspx" -->
<script language="C#" runat="server">

//Copyright 2002-2007 Corey Trager
//Distributed under the terms of the GNU General Public License



DbUtil dbutil;
Security security;

string repos_url = "";

int revision = 0;
int bugid = 0;

string repository_url = "";
string svn_username = "";
string svn_password = "";
string websvn_url = "";

void Page_Init (object sender, EventArgs e) {ViewStateUserKey = Session.SessionID;}

///////////////////////////////////////////////////////////////////////
void Page_Load(Object sender, EventArgs e)
{
	Util.do_not_cache(Response);
	dbutil = new DbUtil();
	security = new Security();
	security.check_security(dbutil, HttpContext.Current, Security.MUST_BE_ADMIN);

    msg.InnerText = "";

    if (!this.IsPostBack)
    {
        bugid = Convert.ToInt32(Util.sanitize_integer(Request["bugid"]));

        if (bugid == 0)
        {
            Response.Write("You need to pass a bugid to this page");
            Response.End();
        }
        hidden_bugid.Value = Convert.ToString(bugid);
        bugid_label.InnerText = Convert.ToString(bugid);
    }
    else
    {
        bugid = Convert.ToInt32(hidden_bugid.Value);

        revision = Convert.ToInt32(Request["rev"]);

        if (revision != 0)
        {

            log_text.InnerText = svn_log(revision, false);
            if (action.Value == "add")
            {
                string xml = svn_log(revision, true);
                update_db(xml);
            }
        }
        else
        {
            msg.InnerText = "Please enter a non-zero revision";
        }
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
string svn_log(int revision, bool xml)
{


	btnet.Util.get_subversion_connection_info(dbutil, bugid,
		ref repository_url,
		ref svn_username,
		ref svn_password,
		ref websvn_url);

	StringBuilder args = new StringBuilder();

	args.Append("log ");
	args.Append(repository_url);
    args.Append(" -r ");
    args.Append(Convert.ToInt32(revision));
	args.Append(" -v");
    if (xml)
    {
        args.Append(" --xml");
    }

	return run_svn(args.ToString());
}

///////////////////////////////////////////////////////////////////////
void update_db(string xml)
{
    XmlDocument doc = new XmlDocument();
    doc.LoadXml(xml);
    XmlNode log_node = doc.ChildNodes[1];

    XmlElement logentry = (XmlElement) log_node.ChildNodes[0];

    // first pass, insert into the revision table

    string author = "";
    string date = "";
    string comment = "";

    foreach(XmlNode node in logentry.ChildNodes)
    {
        if (node.Name == "author") author = node.InnerText;
        else if (node.Name == "date") date = node.InnerText;
        else if (node.Name == "msg") comment = node.InnerText;
    }

    string sql = @"
insert into svn_revisions
    (svnrev_revision,
    svnrev_bug,
    svnrev_repository,
    svnrev_author,
    svnrev_svn_date,
    svnrev_btnet_date,
    svnrev_msg)
    values ($svnrev, $svnbug, '$svnrepos', '$svnauthor', '$svndate', getdate(), '$svnmsg')
    select scope_identity();";

    sql = sql.Replace("$svnrev",Convert.ToString(revision));
    sql = sql.Replace("$svnbug",Convert.ToString(bugid));
    sql = sql.Replace("$svnrepos", repos_url.Replace("'","''"));
    sql = sql.Replace("$svnauthor", author.Replace("'","''"));
    sql = sql.Replace("$svndate", date.Replace("'","''"));
    sql = sql.Replace("$svnmsg", comment.Replace("'","''"));

    int parent = Convert.ToInt32(dbutil.execute_scalar(sql));

    // second pass, insert affected paths
    foreach (XmlNode node in logentry.ChildNodes)
    {
        if (node.Name == "paths")
        {
            string path = "";
            string action = "";
            foreach (XmlNode path_node in node.ChildNodes)
            {
                path = path_node.InnerText;
                action = ((XmlElement)path_node).GetAttribute("action");
                if (action == "M")
                {
                    action = "U";
                }

                if (path.StartsWith("/"))
                {
                    path = path.Substring(1);
                }
                sql = @"
insert into svn_affected_paths
    (svnap_svnrev_id,
    svnap_action,
    svnap_path)
    values ($svnrev, '$svnact', '$svnpath');";

                sql = sql.Replace("$svnrev", Convert.ToString(parent));
                sql = sql.Replace("$svnact", action.Replace("'", "''"));
                sql = sql.Replace("$svnpath", path.Replace("'", "''"));

                dbutil.execute_nonquery(sql);

            }
        }
    }

    msg.InnerText = "Database was updated.";
}



</script>

<html>
<head>
<link rel="StyleSheet" href="btnet.css" type="text/css">
<script>
var asp_form_id = '<% Response.Write(Util.get_form_name()); %>';
function set_action(val)
{
    var frm = document.getElementById(asp_form_id);
    var action = document.getElementById("action");
    action.value = val;
    frm.submit();
    return true;
}
</script>
</head>
<body>
<table border=0><tr><td>
<form class="frm" runat="server">
<span class=lbl>Enter revision to be added to bug <span id="bugid_label" runat="server"></span>
<input type="text" id="rev" value="0" runat="server">
<input type="hidden" id="hidden_bugid" value="0" runat="server" />
<input type="hidden" id="action" name="action" value="" runat="server" />
<p>
<input class="btn" type="button" onclick="return set_action('view')" value="View Revision Info" runat="server">
<p>
<input class="btn" type="button" onclick="return set_action('add')" value="Attach Above Revision to Bug" runat="server">
</form>
</td></tr></table>
<pre>
<span id=log_text runat="server"></span>
</pre>
<div id="msg" runat="server"></div>
<% Response.Write(Application["custom_footer"]); %></body>
</html>
