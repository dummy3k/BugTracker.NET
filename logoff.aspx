<%@ Page language="C#"%>
<!--
Copyright 2002-2009 Corey Trager
Distributed under the terms of the GNU General Public License
-->
<!-- #include file = "inc.aspx" -->


<script runat="server">




///////////////////////////////////////////////////////////////////////
void Page_Load(Object sender, EventArgs e)
{

	Util.do_not_cache(Response);

	Util.set_context(HttpContext.Current);

	
	btnet.DbUtil.get_sqlconnection();

	// delete the session row

	HttpCookie cookie = Request.Cookies["se_id"];

	if (cookie != null)
	{

		// guard against "Sql Injection" exploit
		string se_id = cookie.Value.Replace("'", "''");
		Session[se_id] = 0;

		Session["SelectedBugQuery"] = null;
		Session["bugs"] = null;
		Session["bugs_unfiltered"] = null;
		Session["project"] = null;

	}

	Response.Redirect("default.aspx?msg=logged+off");
}



</script>