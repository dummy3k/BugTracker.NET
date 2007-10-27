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
	security.check_security(dbutil, HttpContext.Current, Security.MUST_BE_ADMIN);

	titl.InnerText = Util.get_setting("AppTitle","BugTracker.NET") + " - "
		+ "delete user defined attribute value";

	string id = Util.sanitize_integer(Request["id"]);
	string confirm = Request.QueryString["confirm"];

	if (confirm == "y")
	{
		// do delete here
		sql = @"delete user_defined_attribute where udf_id = $1";
		sql = sql.Replace("$1", id);
		dbutil.execute_nonquery(sql);
		Server.Transfer ("udfs.aspx");
	}
	else
	{
		sql = @"declare @cnt int
			select @cnt = count(1) from bugs where bg_user_defined_attribute = $1
			select udf_name, @cnt [cnt] from user_defined_attribute where udf_id = $1";
		sql = sql.Replace("$1", id);

		DataRow dr = dbutil.get_datarow(sql);

		if ((int) dr["cnt"] > 0)
		{
			Response.Write ("You can't delete value \""
				+ Convert.ToString(dr["udf_name"])
				+ "\" because some bugs still reference it.");
			Response.End();
		}
		else
		{
			confirm_href.HRef = "delete_udf.aspx?confirm=y&id=" + id;

			confirm_href.InnerText = "confirm delete of \""
				+ Convert.ToString(dr["udf_name"])
				+ "\"";
		}

	}

}




</script>

<html>
<head>
<title id="titl" runat="server">btnet delete user defined attribute value</title>
<link rel="StyleSheet" href="btnet.css" type="text/css">
</head>
<body>
<% security.write_menu(Response, "admin"); %>
<p>
<div class=align>
<p>&nbsp</p>
<a href=udfs.aspx>back to user defined attribute values</a>
<p>
or
<p>
<a id="confirm_href" runat="server" href="">confirm delete</a>
</div>
</body>
</html>


