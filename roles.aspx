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

	ds = dbutil.get_dataset(
		@"select rl_id [id],
		'<a href=edit_role.aspx?id=' + convert(varchar,rl_id) + '>edit</a>' [$no_sort_edit],
		'<a href=delete_role.aspx?id=' + convert(varchar,rl_id) + '>delete</a>' [$no_sort_delete],
		rl_name[desc],
		case when rl_non_admins_can_use = 1 then 'Y' else 'N' end [non-admin<br>can use],
		case when rl_external_user = 1 then 'Y' else 'N' end [external<br>(i.e, customer, not employee)],
		case when rl_can_edit_sql = 1 then 'Y' else 'N' end [can<br>edit sql],
		case when rl_can_delete_bug = 1 then 'Y' else 'N' end [can<br>delete item],
		case when rl_can_edit_and_delete_posts = 1 then 'Y' else 'N' end [can<br>edit/del posts],
		case when rl_can_merge_bugs = 1 then 'Y' else 'N' end [can<br>merge items],
		case when rl_can_mass_edit_bugs = 1 then 'Y' else 'N' end [can<br>mass edit],
		case when rl_can_use_reports = 1 then 'Y' else 'N' end [can<br>use rpts],
		case when rl_can_edit_reports = 1 then 'Y' else 'N' end [can<br>edit rpts],
		case when rl_can_be_assigned_to = 1 then 'Y' else 'N' end [can<br>be assigned to]
		from roles order by rl_name");

}


</script>

<html>
<head>
<title id="titl" runat="server">btnet roles</title>
<link rel="StyleSheet" href="btnet.css" type="text/css">
<script type="text/javascript" language="JavaScript" src="sortable.js"></script>
</head>

<body>
<% security.write_menu(Response, "admin"); %>


<div class=align>
<a href=edit_role.aspx>add new role</a>
</p>
<%

if (ds.Tables[0].Rows.Count > 0)
{
	SortableHtmlTable.create_from_dataset(
		Response, ds, "", "", false);

}
else
{
	Response.Write ("No roles in the database.");
}

%>
</div>
<% Response.Write(Application["custom_footer"]); %></body>
</html>