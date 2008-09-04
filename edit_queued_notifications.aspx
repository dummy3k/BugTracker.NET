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

	if (Request.QueryString["actn"] == "delete")
	{
		sql = @"delete from queued_notifications where qn_status = N'not sent'";
	}
	else if (Request.QueryString["actn"] == "reset")
	{
		sql = @"update queued_notifications set qn_retries = 0 where qn_status = N'not sent'";
	}

	dbutil.execute_nonquery(sql);

	Response.Redirect("notifications.aspx");
}



</script>