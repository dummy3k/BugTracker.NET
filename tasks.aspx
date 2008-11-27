<%@ Page language="C#"%>
<!--
Copyright 2002-2008 Corey Trager
Distributed under the terms of the GNU General Public License
-->
<!-- #include file = "inc.aspx" -->

<script language="C#" runat="server">

int bugid;
DataSet ds;
DbUtil dbutil;
Security security;
int permission_level;
string ses;

void Page_Init (object sender, EventArgs e) {ViewStateUserKey = Session.SessionID;}

void Page_Load(Object sender, EventArgs e)
{

	Util.do_not_cache(Response);
	dbutil = new DbUtil();
	security = new Security();
	security.check_security(dbutil, HttpContext.Current, Security.ANY_USER_OK);
	
	titl.InnerText = Util.get_setting("AppTitle","BugTracker.NET") + " - "
			+ "tasks";
	
	bugid = Convert.ToInt32(Util.sanitize_integer(Request["bugid"]));

	permission_level = Bug.get_bug_permission_level(bugid, security);
	if (permission_level != Security.PERMISSION_ALL)
	{
		Response.Write("You are not allowed to edit tasks");
		Response.End();
	}

	ses = (string) Session["session_cookie"];
	
	string sql = "select * from bug_tasks where tsk_bug = $bugid order by tsk_sort_sequence, tsk_id";
	sql = sql.Replace("$bugid", Convert.ToString(bugid));
	
	ds = dbutil.get_dataset(sql);

}

</script>

<html>
<head>
<title id="titl" runat="server">btnet tasks</title>
<link rel="StyleSheet" href="btnet.css" type="text/css">
<script type="text/javascript" language="JavaScript" src="sortable.js"></script>
</head>
<body>

<div class=align>
<a href=edit_task.aspx?id=0&bugid=<% Response.Write(Convert.ToString(bugid)); %>>add new task</a>
</p>
<%

if (ds.Tables[0].Rows.Count > 0)
{
	SortableHtmlTable.create_from_dataset(
		Response, ds, 
		"edit_task.aspx?ses=" +  ses + "&id=",
		"delete_task.aspx?ses=" +  ses + "&id=");
}
else
{
	Response.Write ("No tasks.");
}

%>
</div>
<% Response.Write(Application["custom_footer"]); %></body>
</html>


