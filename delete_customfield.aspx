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
		+ "delete custom field";

	string id = Util.sanitize_integer(Request["id"]);
	string confirm = Request.QueryString["confirm"];

	if (confirm == "y" && (string) Request["ses"] == (string) Session["session_cookie"])
	{
		// do delete here

		sql = @"select sc.name [column_name], df.name [default_constraint_name]
			from syscolumns sc
			inner join sysobjects so on sc.id = so.id
			left outer join sysobjects df on df.id = sc.cdefault
			where so.name = 'bugs'
			and sc.colorder = $id";

		sql = sql.Replace("$id",id);
		DataRow dr = dbutil.get_datarow(sql);

		// if there is a default, delete it
		if (dr["default_constraint_name"].ToString() != "")
		{
			sql = @"alter table bugs drop constraint [$df]";
			sql = sql.Replace("$df", (string) dr["default_constraint_name"]);
			dbutil.execute_nonquery(sql);
		}


		// delete column itself
		sql = @"alter table bugs drop column [$nm]";
		sql = sql.Replace("$nm", (string) dr["column_name"]);
		dbutil.execute_nonquery(sql);
		Server.Transfer ("customfields.aspx");

		Response.Write(sql);
		Response.End();
	}
	else
	{
		confirm_href.HRef = "delete_customfield.aspx?confirm=y&id=" + id  + "&ses=" + Request["ses"];
	}

}

</script>

<html>
<head>
<title id="titl" runat="server">btnet delete customfield</title>
<link rel="StyleSheet" href="btnet.css" type="text/css">
</head>
<body>
<% security.write_menu(Response, "admin"); %>
<p>
<div class=align>
<p>&nbsp</p>
<a href=customfields.aspx>back to custom fields</a>
<p>
or
<p>
<a id="confirm_href" runat="server" href="">confirm delete</a>
</div>
<% Response.Write(Application["custom_footer"]); %></body>
</html>


