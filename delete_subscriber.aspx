<%@ Page language="C#"%>
<!--
Copyright 2002-2008 Corey Trager
Distributed under the terms of the GNU General Public License
-->
<!-- #include file = "inc.aspx" -->

<script language="C#" runat="server">


Security security;

///////////////////////////////////////////////////////////////////////
void Page_Load(Object sender, EventArgs e)
{

	Util.do_not_cache(Response);
	
	security = new Security();
	security.check_security( HttpContext.Current, Security.MUST_BE_ADMIN);

	if (Request.QueryString["ses"] != (string) Session["session_cookie"])
	{
		Response.Write ("session in URL doesn't match session cookie");
		Response.End();
	}

	string sql = "delete from bug_subscriptions where bs_id = $bs_id";
	sql = sql.Replace("$bs_id", Util.sanitize_integer(Request["bs_id"]));
	btnet.DbUtil.execute_nonquery(sql);

	Response.Redirect("view_subscribers.aspx?id=" + Request["bg_id"]);

}

</script>