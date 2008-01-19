<%@ Page language="C#"%>
<!--
Copyright 2002-2008 Corey Trager
Distributed under the terms of the GNU General Public License
-->
<!-- #include file = "inc.aspx" -->


<script runat="server">

DbUtil dbutil;


///////////////////////////////////////////////////////////////////////
void Page_Load(Object sender, EventArgs e)
{

	Util.do_not_cache(Response);

	dbutil = new DbUtil();
	dbutil.get_sqlconnection();

	// delete the session row

	HttpCookie cookie = Request.Cookies["se_id"];

	if (cookie != null)
	{
		// guard against "Sql Injection" exploit
		string se_id = cookie.Value.Replace("'", "''");
		string sql = @"delete from sessions
			where se_id = N'$se'
			or datediff(d, se_date, getdate()) > 2";
		sql = sql.Replace("$se", se_id);
		dbutil.execute_nonquery(sql);


		Session["SelectedBugQuery"] = null;
		Session["bugs"] = null;
		Session["project"] = null;

	}

	Response.Redirect("default.aspx?msg=logged+off");
}



</script>