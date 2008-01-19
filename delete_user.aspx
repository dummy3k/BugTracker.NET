<%@ Page language="C#"%>
<!--
Copyright 2002-2008 Corey Trager
Distributed under the terms of the GNU General Public License
-->
<!-- #include file = "inc.aspx" -->

<script language="C#" runat="server">


String sql;
DbUtil dbutil;
Security security;

void Page_Init (object sender, EventArgs e) {ViewStateUserKey = Session.SessionID;}

///////////////////////////////////////////////////////////////////////
void Page_Load(Object sender, EventArgs e)
{

	Util.do_not_cache(Response);
	dbutil = new DbUtil();
	security = new Security();
	security.check_security(dbutil, HttpContext.Current, Security.MUST_BE_ADMIN_OR_PROJECT_ADMIN);

	string id = Util.sanitize_integer(Request["id"]);

	if (!security.this_is_admin)
	{
		sql = @"select us_created_user, us_admin from users where us_id = $us";
		sql = sql.Replace("$us", id);
		DataRow dr = dbutil.get_datarow(sql);

		if (security.this_usid != (int) dr["us_created_user"])
		{
			Response.Write ("You not allowed to delete this user, because you didn't create it.");
			Response.End();
		}
		else if ((int) dr["us_admin"] == 1)
		{
			Response.Write ("You not allowed to delete this user, because it is an admin.");
			Response.End();
		}
	}

	if (IsPostBack)
	{
		// do delete here
		sql = @"delete users where us_id = $us";
		sql = sql.Replace("$us", row_id.Value);
		dbutil.execute_nonquery(sql);
		Server.Transfer ("users.aspx");
	}
	else
	{
		titl.InnerText = Util.get_setting("AppTitle","BugTracker.NET") + " - "
			+ "delete user";

		sql = @"declare @cnt int
			select @cnt = count(1) from bugs where bg_reported_user = $us or bg_assigned_to_user = $us
			select us_username, @cnt [cnt] from users where us_id = $us";
		sql = sql.Replace("$us", id);

		DataRow dr = dbutil.get_datarow(sql);

		if ((int) dr["cnt"] > 0)
		{
			Response.Write ("You can't delete user \""
				+ Convert.ToString(dr["us_username"])
				+ "\" because some bugs still reference it.");
			Response.End();
		}
		else
		{

			confirm_href.InnerText = "confirm delete of \""
				+ Convert.ToString(dr["us_username"])
				+ "\"";

			row_id.Value = id;

		}
	}

}


</script>

<html>
<head>
<title id="titl" runat="server">btnet delete user</title>
<link rel="StyleSheet" href="btnet.css" type="text/css">
</head>
<body>
<% security.write_menu(Response, "admin"); %>
<p>
<div class=align>
<p>&nbsp</p>
<a href=users.aspx>back to users</a>

<p>or<p>

<script>
function submit_form()
{
    var frm = document.getElementById("frm");
    frm.submit();
    return true;
}

</script>
<form runat="server" id="frm">
<a id="confirm_href" runat="server" href="javascript: submit_form()"></a>
<input type="hidden" id="row_id" runat="server">
</form>

</div>
<% Response.Write(Application["custom_footer"]); %></body>
</html>


