<%@ Page language="C#"%>
<!--
Copyright 2002-2008 Corey Trager
Distributed under the terms of the GNU General Public License
-->
<!-- #include file = "inc.aspx" -->

<script language="C#" runat="server">

DbUtil dbutil;
Security security;

///////////////////////////////////////////////////////////////////////
void Page_Load(Object sender, EventArgs e)
{

	Util.do_not_cache(Response);
	dbutil = new DbUtil();
	security = new Security();
	security.check_security(dbutil, HttpContext.Current, Security.MUST_BE_ADMIN);

	if (Request.QueryString["ses"] != (string) Session["session_cookie"])
	{
		Response.Write ("session in URL doesn't match session cookie");
		Response.End();
	}

	string sql = "delete from bug_subscriptions where bs_id = $bs_id";
	sql = sql.Replace("$bs_id", Util.sanitize_integer(Request["bs_id"]));
	dbutil.execute_nonquery(sql);

	Response.Redirect("view_subscribers.aspx?id=" + Request["bg_id"]);

}

</script>