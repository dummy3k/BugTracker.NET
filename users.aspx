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

	dbutil = new DbUtil();

	Util.do_not_cache(Response);
	security = new Security();
	security.check_security(dbutil, HttpContext.Current, Security.MUST_BE_ADMIN_OR_PROJECT_ADMIN);

	titl.InnerText = Util.get_setting("AppTitle","BugTracker.NET") + " - "
		+ "users";

	string sql;

	if (security.this_is_admin)
	{
		sql = @"
			select distinct pu_user
			into #t
			from
			project_user_xref
			where pu_admin = 1;

			select u.us_id [id],
			'<a href=edit_user.aspx?copy=y&id=' + convert(varchar,u.us_id) + '>copy</a>' [add<br>like<br>this],

			u.us_username [username],
			isnull(u.us_firstname,'') + ' ' + isnull(u.us_lastname,'') [name],
			case when u.us_admin = 1 then 'Y' else 'N' end [admin],
			case when pu_user is null then 'N' else 'Y' end [project<br>admin],
			case when u.us_active = 1 then 'Y' else 'N' end [active],
			case when u.us_external_user = 1 then 'Y' else 'N' end [external<br>],
			case when u.us_can_edit_sql = 1 then 'Y' else 'N' end [can<br>edit<br>sql],
			case when u.us_can_delete_bug = 1 then 'Y' else 'N' end [can<br>delete<br>item],
			case when u.us_can_edit_and_delete_posts = 1 then 'Y' else 'N' end [can<br>edit/del<br>posts],
			case when u.us_can_merge_bugs = 1 then 'Y' else 'N' end [can<br>merge<br>items],
			case when u.us_can_mass_edit_bugs = 1 then 'Y' else 'N' end [can<br>mass<br>edit],
			case when u.us_can_use_reports = 1 then 'Y' else 'N' end [can<br>use<br>rpts],
			case when u.us_can_edit_reports = 1 then 'Y' else 'N' end [can<br>edit<br>rpts],
			case when u.us_can_be_assigned_to = 1 then 'Y' else 'N' end [can<br>be<br>assigned<br>to],
			isnull(pj_name,'') [forced<br>project],
			isnull(qu_desc,'') [default query],
			case when u.us_enable_notifications = 1 then 'Y' else 'N' end [notif-<br>ications],

			u2.us_username [created<br>by],
			u.us_id [hidden]

			from users u
			left outer join queries on u.us_default_query = qu_id
			left outer join projects on u.us_forced_project = pj_id
			left outer join users u2 on u.us_created_user = u2.us_id
			left outer join #t on u.us_id = pu_user
			where u.us_active in (1 $inactive)
			order by u.us_username;

			drop table #t";
	}
	else
	{
		sql = @"
			select distinct pu_user
			into #t
			from
			project_user_xref
			where pu_admin = 1;

			select u.us_id [id],
			'<a href=edit_user.aspx?copy=y&id=' + convert(varchar,u.us_id) + '>copy</a>' [add<br>like<br>this],
			u.us_username [username],
			isnull(u.us_firstname,'') + ' ' + isnull(u.us_lastname,'') [name],
			case when u.us_admin = 1 then 'Y' else 'N' end [admin],
			case when pu_user is null then 'N' else 'Y' end [project<br>admin],
			case when u.us_active = 1 then 'Y' else 'N' end [active],
			case when u.us_external_user = 1 then 'Y' else 'N' end [external<br>],
			case when u.us_can_edit_sql = 1 then 'Y' else 'N' end [can<br>edit<br>sql],
			case when u.us_can_delete_bug = 1 then 'Y' else 'N' end [can<br>delete<br>item],
			case when u.us_can_edit_and_delete_posts = 1 then 'Y' else 'N' end [can<br>edit/del<br>posts],
			case when u.us_can_merge_bugs = 1 then 'Y' else 'N' end [can<br>merge<br>items],
			case when u.us_can_mass_edit_bugs = 1 then 'Y' else 'N' end [can<br>mass<br>edit],
			case when u.us_can_use_reports = 1 then 'Y' else 'N' end [can<br>use<br>rpts],
			case when u.us_can_edit_reports = 1 then 'Y' else 'N' end [can<br>edit<br>rpts],
			case when u.us_can_be_assigned_to = 1 then 'Y' else 'N' end [can<br>be<br>assigned<br>to],
			isnull(pj_name,'') [forced<br>project],
			isnull(qu_desc,'') [default query],
			case when u.us_enable_notifications = 1 then 'Y' else 'N' end [notif-<br>ications],

			us_id [hidden]
			from users u
			left outer join queries on us_default_query = qu_id
			left outer join projects on us_forced_project = pj_id
			left outer join #t on us_id = pu_user
			where us_created_user = $us
			and us_active in (1 $inactive)
			order by us_username;

			drop table #t";
	}

	if (!IsPostBack)
	{
		HttpCookie cookie = Request.Cookies["hide_inactive_users"];
		if (cookie != null)
		{
			if (cookie.Value == "1")
			{
				hide_inactive_users.Checked = true;
			}
		}
	}

	if (hide_inactive_users.Checked)
	{
		Response.Cookies["hide_inactive_users"].Value = "1";
		sql = sql.Replace("$inactive", "");
	}
	else
	{
		Response.Cookies["hide_inactive_users"].Value = "0";
		sql = sql.Replace("$inactive", ",0");
	}

	sql = sql.Replace("$us", Convert.ToString(security.this_usid));
	ds = dbutil.get_dataset(sql);

}


</script>

<html>
<head>
<title id="titl" runat="server">btnet users</title>
<link rel="StyleSheet" href="btnet.css" type="text/css">
<script type="text/javascript" language="JavaScript" src="sortable.js"></script>
</head>

<body>
<% security.write_menu(Response, "admin"); %>

<div class=align>

<table border=0 width=80%><tr>
<td align=left>
	<a href=edit_user.aspx>add new user </a>
<td align=right>
	<form runat="server">
	<span class=lbl>hide inactive users:</span>
	<asp:CheckBox id="hide_inactive_users" runat="server" AutoPostBack="true" OnCheckedChanged="Page_Load"/>
	</form>
</table>

<%

if (ds.Tables[0].Rows.Count > 0)
{
	SortableHtmlTable.create_from_dataset(
		Response, ds, "edit_user.aspx?id=", "delete_user.aspx?id=", false);

}
else
{
	Response.Write ("No users in the database.");
}
%>
</div>
</body>
</html>