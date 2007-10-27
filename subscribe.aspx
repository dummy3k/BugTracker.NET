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

	dbutil = new DbUtil();
	security = new Security();
	security.check_security(dbutil, HttpContext.Current, Security.ANY_USER_OK_EXCEPT_GUEST);


	if (Request.QueryString["action"] == "1")
	{
		sql = @"insert into bug_subscriptions (bs_bug, bs_user)
			values($bg, $us)";
	}
	else
	{
		sql = @"delete from bug_subscriptions
			where bs_bug = $bg and bs_user = $us";
	}

	sql = sql.Replace("$bg", Util.sanitize_integer(Request["id"]));
	sql = sql.Replace("$us", Convert.ToString(security.this_usid));
	dbutil.execute_nonquery(sql);
	Response.Redirect ("edit_bug.aspx?id=" + Request["id"]);

}



</script>