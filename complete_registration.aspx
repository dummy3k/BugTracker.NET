<%@ Page language="C#"%>
<!--
Copyright 2002-2008 Corey Trager
Distributed under the terms of the GNU General Public License
-->
<!-- #include file = "inc.aspx" -->

<script language="C#" runat="server">




///////////////////////////////////////////////////////////////////////
void Page_Load(Object sender, EventArgs e)
{

	Util.set_context(HttpContext.Current);
	Util.do_not_cache(Response);

	

	string guid = Request["id"];

	string sql = @"
declare @expiration datetime
set @expiration = dateadd(n,-$minutes,getdate())

select *,
	case when el_date < @expiration then 1 else 0 end [expired]
	from emailed_links
	where el_id = '$guid'

delete from emailed_links
	where el_date < dateadd(n,-240,getdate())";

	sql = sql.Replace("$minutes",Util.get_setting("RegistrationExpiration","20"));
	sql = sql.Replace("$guid",guid.Replace("'","''"));

	DataRow dr = btnet.DbUtil.get_datarow(sql);

	if (dr == null)
	{
		msg.InnerHtml = "The link you clicked on is expired or invalid.<br>Please start over again.";
	}
	else if ((int) dr["expired"] == 1)
	{
		msg.InnerHtml = "The link you clicked has expired.<br>Please start over again.";
	}
	else
	{
		// insert the user now, delete the temp link
		sql = @"

declare @template_user_id int
select @template_user_id = us_id from users where us_username = N'$template'

insert into users
	(us_username, us_email, us_firstname, us_lastname, us_salt, us_password,
	us_default_query,
	us_enable_notifications,
	us_auto_subscribe,
	us_auto_subscribe_own_bugs,
	us_auto_subscribe_reported_bugs,
	us_send_notifications_to_self,
	us_active,
	us_bugs_per_page,
	us_forced_project,
	us_reported_notifications,
	us_assigned_notifications,
	us_subscribed_notifications,
	us_use_fckeditor,
	us_enable_bug_list_popups,
	us_org)

select
	N'$username', N'$email', N'$firstname', N'$lastname', $salt, N'$password',
	us_default_query,
	us_enable_notifications,
	us_auto_subscribe,
	us_auto_subscribe_own_bugs,
	us_auto_subscribe_reported_bugs,
	us_send_notifications_to_self,
	1, -- active
	us_bugs_per_page,
	us_forced_project,
	us_reported_notifications,
	us_assigned_notifications,
	us_subscribed_notifications,
	us_use_fckeditor,
	us_enable_bug_list_popups,
	us_org
	from users where us_id = @template_user_id

declare @new_user_id int
select @new_user_id = scope_identity()

insert into project_user_xref
	(pu_project, pu_user, pu_auto_subscribe, pu_permission_level, pu_admin)

select pu_project, @new_user_id, pu_auto_subscribe, pu_permission_level, pu_admin
	from project_user_xref
	where pu_user = @template_user_id

delete from emailed_links where el_id = '$guid'";

		sql = sql.Replace("$username", ((string) dr["el_username"]).Replace("'","''"));
		sql = sql.Replace("$email", ((string) dr["el_email"]).Replace("'","''"));
		sql = sql.Replace("$firstname", ((string) dr["el_firstname"]).Replace("'","''"));
		sql = sql.Replace("$lastname", ((string) dr["el_lastname"]).Replace("'","''"));
		sql = sql.Replace("$salt", Convert.ToString((int)dr["el_salt"]));
		sql = sql.Replace("$password", (string) dr["el_password"]);

		sql = sql.Replace("$guid",guid.Replace("'","''"));
		sql = sql.Replace("$template", Util.get_setting("SelfRegisteredUserTemplate","[NO SelfRegisteredUserTemplate!]"));

		btnet.DbUtil.execute_nonquery(sql);
		msg.InnerHtml = "Your registration is complete.";
	}

}


</script>

<html>
<head>
<title id="titl" runat="server">btnet change password</title>
<link rel="StyleSheet" href="btnet.css" type="text/css">
</head>
<body>
<table border=0><tr>

<%

Response.Write (Application["custom_logo"]);

%>

</table>


<div align="center">
<table border=0><tr><td>

<div runat="server" class=err id="msg">&nbsp;</div>
<p>
<a href="default.aspx">Go to login page</a>

</td></tr></table>

</div>
</body>
</html>