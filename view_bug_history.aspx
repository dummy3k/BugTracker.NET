<%@ Page language="C#"%>
<!--
Copyright 2002-2007 Corey Trager
Distributed under the terms of the GNU General Public License
-->
<!-- #include file = "inc.aspx" -->
<script language="C#" runat="server">

DataSet ds;
DbUtil dbutil;
Security security;

void Page_Load(Object sender, EventArgs e)
{

	Util.do_not_cache(Response);
	dbutil = new DbUtil();
	security = new Security();
	security.check_security(dbutil, HttpContext.Current, Security.ANY_USER_OK);

	titl.InnerText = Util.get_setting("AppTitle","BugTracker.NET") + " - "
		+ "view history";

	string string_bg_id = Request["id"];

	int permission_level = Bug.get_bug_permission_level(Convert.ToInt32(string_bg_id), security);
	if (permission_level == Security.PERMISSION_NONE)
	{
		Response.Write("You are not allowed to view this item");
		Response.End();
	}

	string sql = @"select
		bp_comment [change],
		us_username [user],
		bp_date [date]
		from bug_posts
		inner join users on bp_user = us_id
		where bp_bug = $bg
		and bp_type = 'update'
		order by bp_date " + Util.get_setting("CommentSortOrder","desc");

	sql = sql.Replace("$bg", Util.sanitize_integer(string_bg_id));

	ds = dbutil.get_dataset(sql);
}



</script>

<html>
<head>
<title id="titl" runat="server">btnet bug history</title>
<link rel="StyleSheet" href="btnet.css" type="text/css">
<script type="text/javascript" language="JavaScript" src="sortable.js"></script>
</head>

<body width=600>
<div class=align>
History of Changes
<p>
<%
if (ds.Tables[0].Rows.Count > 0)
{
	SortableHtmlTable.create_from_dataset(
		Response, ds, "", "");

}
else
{
	Response.Write ("No history for this bug.");
}
%>
</div>
</body>
</html>