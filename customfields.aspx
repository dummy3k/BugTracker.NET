<%@ Page language="C#"%>
<!--
Copyright 2002-2007 Corey Trager
Distributed under the terms of the GNU General Public License
-->
<!-- #include file = "inc.aspx" -->

<script language="C#" runat="server">


DataSet ds;
DbUtil dbutil;
Security security;

void Page_Load(Object sender, EventArgs e)
{

	Util.do_not_cache(Response);
	dbutil = new DbUtil();
	security = new Security();
	security.check_security(dbutil, HttpContext.Current, Security.MUST_BE_ADMIN);

	ds = Util.get_custom_columns(dbutil);

}


</script>

<html>
<head>
<title id="titl" runat="server">btnet custom fields</title>
<link rel="StyleSheet" href="btnet.css" type="text/css">
<script type="text/javascript" language="JavaScript" src="sortable.js"></script>
</head>

<body>
<% security.write_menu(Response, "admin"); %>


<div class=align>
<a href=add_customfield.aspx>add new custom field</a>
</p>
<%

if (ds.Tables[0].Rows.Count > 0)
{
	SortableHtmlTable.create_from_dataset(
		Response, ds, "edit_customfield.aspx?id=", "delete_customfield.aspx?id=");

}
else
{
	Response.Write ("No custom fields.");
}

%>
</div>
</body>
</html>