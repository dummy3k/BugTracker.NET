<%@ Page language="C#"%>
<!--
Copyright 2002-2007 Corey Trager
Distributed under the terms of the GNU General Public License
-->
<!-- #include file = "inc.aspx" -->

<script language="C#" runat="server">


String sql;
DbUtil dbutil;
Security security;

///////////////////////////////////////////////////////////////////////
void Page_Load(Object sender, EventArgs e)
{

	Util.do_not_cache(Response);
	dbutil = new DbUtil();
	security = new Security();

	security.check_security(dbutil, HttpContext.Current, Security.ANY_USER_OK_EXCEPT_GUEST);

	if (security.this_is_admin || security.this_can_edit_and_delete_posts)
	{
		//
	}
	else
	{
		Response.Write ("You are not allowed to use this page.");
		Response.End();
	}


	titl.InnerText = Util.get_setting("AppTitle","BugTracker.NET") + " - "
		+ "delete comment";


	string id = Util.sanitize_integer(Request["id"]);

	string bug_id = Util.sanitize_integer(Request["bug_id"]);

	int permission_level = btnet.Bug.get_bug_permission_level(Convert.ToInt32(bug_id), security);
	if (permission_level != Security.PERMISSION_ALL)
	{
		Response.Write("You are not allowed to edit this item");
		Response.End();
	}


	string confirm = Request.QueryString["confirm"];

	if (confirm == "y")
	{
		// do delete here

		sql = @"delete bug_posts where bp_id = $1";
		sql = sql.Replace("$1", id);
		dbutil.execute_nonquery(sql);
		Response.Redirect ("edit_bug.aspx?id=" + bug_id);
	}
	else
	{
		back_href.HRef = "edit_bug.aspx?id=" + bug_id;
		confirm_href.HRef = "delete_comment.aspx?confirm=y&id=" + id + "&bug_id=" + bug_id;

		sql = @"select bp_comment from bug_posts where bp_id = $1";
		sql = sql.Replace("$1", id);

		DataRow dr = dbutil.get_datarow(sql);

		// show the first few chars of the comment
		string s = Convert.ToString(dr["bp_comment"]);
		int len = 20;
		if (s.Length < len) {len = s.Length;}

		confirm_href.InnerText = "confirm delete of comment: "
				+ s.Substring(0,len)
				+ "...";

	}


}

</script>

<html>
<head>
<title id="titl" runat="server">btnet edit attachment</title>
<link rel="StyleSheet" href="btnet.css" type="text/css">
</head>
<body>
<% security.write_menu(Response, Util.get_setting("PluralBugLabel","bugs")); %>
<p>
<div class=align>
<p>&nbsp</p>
<a id="back_href" runat="server" href="">back to <% Response.Write(Util.get_setting("SingularBugLabel","bug")); %></a>
<p>
or
<p>
<a id="confirm_href" runat="server" href="">confirm delete</a>
</div>
<% Response.Write(Application["custom_footer"]); %></body>
</html>


