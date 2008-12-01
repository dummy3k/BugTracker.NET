<%@ Page language="C#"%>
<!--
Copyright 2002-2008 Corey Trager
Distributed under the terms of the GNU General Public License
-->
<!-- #include file = "inc.aspx" -->
<script language="C#" runat="server">

DataSet ds;

Security security;
int bugid;

void Page_Load(Object sender, EventArgs e)
{

	Util.do_not_cache(Response);
	
	security = new Security();
	security.check_security( HttpContext.Current, Security.ANY_USER_OK);

    bugid = Convert.ToInt32(Util.sanitize_integer(Request["id"]));

    string repository_url = "";
    string svn_username = "";
    string svn_password = "";
    string websvn_url = "";

    btnet.Util.get_subversion_connection_info(bugid,
    	ref repository_url,
    	ref svn_username,
    	ref svn_password,
    	ref websvn_url);


    int permission_level = Bug.get_bug_permission_level(bugid, security);
    if (permission_level == Security.PERMISSION_NONE)
    {
        Response.Write("You are not allowed to view this item");
        Response.End();
    }

	titl.InnerText = Util.get_setting("AppTitle","BugTracker.NET") + " - "
		+ "view svn file revisions";


	string sql = @"
		select
		svnrev_revision [revision],
		--svnrev_repository [repository],
		svnap_action [action],
		svnap_path [file],
		svnrev_author [user],
		svnrev_svn_date [revision date],
		replace(substring(svnrev_msg,1,4000),char(13),'<br>') [msg]";


	if (repository_url != "")
	{
		sql += @",
			case when svnap_action not like '%D%' and svnap_action not like 'A%' then
				'<a target=_blank href=svn_diff.aspx?id=' + convert(varchar,svnap_id) + '>diff</a>'
				else
				''
			end [view<br>diff],

			case when svnap_action not like '%D%' then
			'<a target=_blank href=svn_log.aspx?id=' + convert(varchar,svnap_id) + '>history</a>'
				else
				''
			end [view<br>history<br>(svn log)]";
	}


	if (websvn_url != "")
	{
		sql += ",\n '<a target=_blank href=\"" + websvn_url + "\">WebSvn</a>' [WebSvn<br>URL]";
		sql = sql.Replace("$PATH","' + svnap_path + '");
		sql = sql.Replace("$REV", "' + convert(varchar,svnrev_revision) + '");
	}

	sql += @"
		from svn_revisions
		inner join svn_affected_paths on svnap_svnrev_id = svnrev_id
		where svnrev_bug = $bg
		order by svnrev_revision desc, svnap_path";

	sql = sql.Replace("$bg", Convert.ToString(bugid));

	ds = btnet.DbUtil.get_dataset(sql);
}



</script>

<html>
<head>
<title id="titl" runat="server">btnet view svn revisions</title>
<link rel="StyleSheet" href="btnet.css" type="text/css">
<script type="text/javascript" language="JavaScript" src="sortable.js"></script>
</head>

<body width=600>
<div class=align>
File Revisions for <% Response.Write(btnet.Util.get_setting("SingularBugLabel","bug")); %>&nbsp;<% Response.Write(Convert.ToString(bugid)); %>
<p>
<%
if (ds.Tables[0].Rows.Count > 0)
{
	SortableHtmlTable.create_from_dataset(
		Response, ds, "", "", false);

}
else
{
	Response.Write ("No revisions.");
}
%>
</div>
<%

    if (security.user.is_admin)
    {
        Response.Write("<a href=add_svn_revision.aspx?bugid=" + Convert.ToString(bugid) + ">manually link revision to this bug</a>");

    }

     %>
</body>
</html>