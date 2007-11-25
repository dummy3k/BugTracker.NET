<%@ Page language="C#"%>
<!--
Copyright 2002-2007 Corey Trager
Distributed under the terms of the GNU General Public License
-->
<!-- #include file = "inc.aspx" -->

<script language="C#" runat="server">

int id;
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
		+ "edit role";

	msg.InnerText = "";

	string var = Request.QueryString["id"];
	if (var == null)
	{
		id = 0;
	}
	else
	{
		id = Convert.ToInt32(var);
	}

	if (!IsPostBack)
	{

		// add or edit?
		if (id == 0)
		{
			sub.Value = "Create";
		}
		else
		{
			sub.Value = "Update";

			// Get this entry's data from the db and fill in the form

			sql = @"select * from roles where rl_id = $rl_id";
			sql = sql.Replace("$rl_id", Convert.ToString(id));
			DataRow dr = dbutil.get_datarow(sql);

			// Fill in this form
			name.Value = (string) dr["rl_name"];
			non_admins_can_use.Checked = Convert.ToBoolean((int)dr["rl_non_admins_can_use"]);
			external_user.Checked = Convert.ToBoolean((int)dr["rl_external_user"]);
			can_edit_sql.Checked = Convert.ToBoolean((int)dr["rl_can_edit_sql"]);
			can_delete_bug.Checked = Convert.ToBoolean((int)dr["rl_can_delete_bug"]);
			can_edit_and_delete_posts.Checked = Convert.ToBoolean((int)dr["rl_can_edit_and_delete_posts"]);
			can_merge_bugs.Checked = Convert.ToBoolean((int)dr["rl_can_merge_bugs"]);
			can_mass_edit_bugs.Checked = Convert.ToBoolean((int)dr["rl_can_mass_edit_bugs"]);
			can_use_reports.Checked = Convert.ToBoolean((int)dr["rl_can_use_reports"]);
			can_edit_reports.Checked = Convert.ToBoolean((int)dr["rl_can_edit_reports"]);
			can_be_assigned_to.Checked = Convert.ToBoolean((int)dr["rl_can_be_assigned_to"]);
		}
	}

}


///////////////////////////////////////////////////////////////////////
Boolean validate()
{

	Boolean good = true;
	if (name.Value == "")
	{
		good = false;
		name_err.InnerText = "Name is required.";
	}
	else
	{
		name_err.InnerText = "";
	}


	return good;
}

///////////////////////////////////////////////////////////////////////
void on_update (Object sender, EventArgs e)
{

	Boolean good = validate();

	if (good)
	{
		if (id == 0)  // insert new
		{
			sql = @"insert into roles
			(rl_name,
			rl_non_admins_can_use,
			rl_external_user,
			rl_can_edit_sql,
			rl_can_delete_bug,
			rl_can_edit_and_delete_posts,
			rl_can_merge_bugs,
			rl_can_mass_edit_bugs,
			rl_can_use_reports,
			rl_can_edit_reports,
			rl_can_be_assigned_to)
			values (N'$nam', $non,
			$ext, $ces, $cdb,
			$cep, $cmb, $cme,
			$cur, $cer, $cba)";
		}
		else // edit existing
		{

			sql = @"update roles set
			rl_name = N'$nam',
			rl_non_admins_can_use = $non,
			rl_external_user = $ext,
			rl_can_edit_sql = $ces,
			rl_can_delete_bug = $cdb,
			rl_can_edit_and_delete_posts = $cep,
			rl_can_merge_bugs = $cmb,
			rl_can_mass_edit_bugs = $cme,
			rl_can_use_reports = $cur,
			rl_can_edit_reports = $cer,
			rl_can_be_assigned_to = $cba
			where rl_id = $rl_id";

			sql = sql.Replace("$rl_id", Convert.ToString(id));

		}

		sql = sql.Replace("$nam", name.Value.Replace("'","''"));
		sql = sql.Replace("$non", Util.bool_to_string(non_admins_can_use.Checked));
		sql = sql.Replace("$ext", Util.bool_to_string(external_user.Checked));
		sql = sql.Replace("$ces", Util.bool_to_string(can_edit_sql.Checked));
		sql = sql.Replace("$cdb", Util.bool_to_string(can_delete_bug.Checked));
		sql = sql.Replace("$cep", Util.bool_to_string(can_edit_and_delete_posts.Checked));
		sql = sql.Replace("$cmb", Util.bool_to_string(can_merge_bugs.Checked));
		sql = sql.Replace("$cme", Util.bool_to_string(can_mass_edit_bugs.Checked));
		sql = sql.Replace("$cur", Util.bool_to_string(can_use_reports.Checked));
		sql = sql.Replace("$cer", Util.bool_to_string(can_edit_reports.Checked));
		sql = sql.Replace("$cba", Util.bool_to_string(can_be_assigned_to.Checked));


		dbutil.execute_nonquery(sql);
		Server.Transfer ("roles.aspx");

	}
	else
	{
		if (id == 0)  // insert new
		{
			msg.InnerText = "role was not created.";
		}
		else // edit existing
		{
			msg.InnerText = "role was not updated.";
		}

	}

}

</script>

<html>
<head>
<title id="titl" runat="server">btnet edit role</title>
<link rel="StyleSheet" href="btnet.css" type="text/css">
</head>
<body>
<% security.write_menu(Response, "admin"); %>


<div class=align><table border=0><tr><td>
<a href=roles.aspx>back to roles</a>
<form class=frm runat="server">
	<table border=0>

	<tr>
	<td class=lbl>Role Name:</td>
	<td><input runat="server" type=text class=txt id="name" maxlength=30 size=30></td>
	<td runat="server" class=err id="name_err">&nbsp;</td>
	</tr>

	<tr>
	<td colspan=3>
	&nbsp;
	</td>
	</tr>

	<tr>
	<td><asp:checkbox runat="server" class=txt id="non_admins_can_use"/></td>
	<td class=lbl>Non-admins allowed to add users can use this role when adding users</td>
	<td>&nbsp</td>
	</tr>

	<tr>
	<td colspan=3>
	<br><br>
	<div class=smallnote style="width: 400px;">Use the following settings to control permissions for non-admins.<br>Admins have all permissions regardless of these settings.<br>
	</div>
	</td>
	</tr>

	<tr>
	<td><asp:checkbox runat="server" class=txt id="external_user"/></td>
	<td class=lbl>External user&nbsp;&nbsp; <span class=smallnote>(External users cannot view posts marked "Visible for internal usrs only")</span></td>
	<td>&nbsp</td>
	</tr>
	<tr>
	<td><asp:checkbox runat="server" class=txt id="can_edit_sql"/></td>
	<td class=lbl>Can edit sql and create/edit queries for everybody</td>
	<td>&nbsp</td>
	</tr>
	<tr>
	<td><asp:checkbox runat="server" class=txt id="can_delete_bug"/></td>
	<td class=lbl>Can delete bugs</td>
	<td>&nbsp</td>
	</tr>

	<tr>
	<td><asp:checkbox runat="server" class=txt id="can_edit_and_delete_posts"/></td>
	<td class=lbl>Can edit and delete comments and attachments</td>
	<td>&nbsp</td>
	</tr>
	<tr>
	<td><asp:checkbox runat="server" class=txt id="can_merge_bugs"/></td>
	<td class=lbl>Can merge two bugs into one</td>
	<td>&nbsp</td>
	</tr>
	<tr>
	<td><asp:checkbox runat="server" class=txt id="can_mass_edit_bugs"/></td>
	<td class=lbl>Can mass edit bugs on search page</td>
	<td>&nbsp</td>
	</tr>

	<tr>
	<td><asp:checkbox runat="server" class=txt id="can_use_reports"/></td>
	<td class=lbl>Can use reports</td>
	<td>&nbsp</td>
	</tr>
	<tr>
	<td><asp:checkbox runat="server" class=txt id="can_edit_reports"/></td>
	<td class=lbl>Can create/edit reports</td>
	<td>&nbsp</td>
	</tr>

	<tr>
	<td colspan=3>
	&nbsp;
	</td>
	</tr>

	<tr>
	<td><asp:checkbox runat="server" class=txt id="can_be_assigned_to"/></td>
	<td class=lbl>Appears in "assigned to" dropdown in edit bug page</td>
	<td>&nbsp</td>
	</tr>

	<tr><td colspan=3 align=left>
	<span runat="server" class=err id="msg">&nbsp;</span>
	</td></tr>

	<tr>
	<td colspan=2 align=center>
	<input runat="server" class=btn type=submit id="sub" value="Create or Edit" OnServerClick="on_update">
	<td>&nbsp</td>
	</td>
	</tr>
	</td></tr></table>
</form>
</td></tr></table></div>
<% Response.Write(Application["custom_footer"]); %></body>
</html>


