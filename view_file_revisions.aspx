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
		+ "view subscribers";

	// clean up bug subscriptions that no longer fit the security restrictions

	string sql = @"

		select bfr_revision [revision],
		bfr_action [action],
		bfr_file [file],
		bfr_date [revision date]
		from bug_file_revisions
		where bfr_bug = $bg
		order by bfr_revision desc, bfr_file";

	sql = sql.Replace("$bg", Util.sanitize_integer(Request["bugid"]));

	ds = dbutil.get_dataset(sql);
}



</script>

<html>
<head>
<title id="titl" runat="server">btnet view subscribers</title>
<link rel="StyleSheet" href="btnet.css" type="text/css">
<script type="text/javascript" language="JavaScript" src="sortable.js"></script>
</head>

<body width=600>
<div class=align>
File Revisions
<p>
<%
if (ds.Tables[0].Rows.Count > 0)
{
	SortableHtmlTable.create_from_dataset(
		Response, ds, "", "");

}
else
{
	Response.Write ("No revisions for this bug.");
}
%>
</div>
</body>
</html>