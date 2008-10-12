<%@ Page language="C#"%>
<!--
Copyright 2002-2008 Corey Trager
Distributed under the terms of the GNU General Public License
-->
<!-- #include file = "inc.aspx" -->

<script language="C#" runat="server">

int id;
String sql;

DbUtil dbutil;
Security security;

void Page_Init (object sender, EventArgs e) {ViewStateUserKey = Session.SessionID;}


///////////////////////////////////////////////////////////////////////
void Page_Load(Object sender, EventArgs e)
{

	Util.do_not_cache(Response);
	dbutil = new DbUtil();
	security = new Security();
	security.check_security(dbutil, HttpContext.Current, Security.MUST_BE_ADMIN);

	titl.InnerText = Util.get_setting("AppTitle","BugTracker.NET") + " - "
		+ "edit organization";

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
			//other_orgs_permission_level.SelectedIndex = 2;
			can_be_assigned_to.Checked = true;
			other_orgs.SelectedValue = "2";

			project_field.SelectedValue = "2";
			org_field.SelectedValue = "2";
			category_field.SelectedValue = "2";
			tags_field.SelectedValue = "2";
			priority_field.SelectedValue = "2";
			status_field.SelectedValue = "2";
			assigned_to_field.SelectedValue = "2";
			udf_field.SelectedValue = "2";
		}
		else
		{
			sub.Value = "Update";

			// Get this entry's data from the db and fill in the form

			sql = @"select * from orgs where og_id = $og_id";
			sql = sql.Replace("$og_id", Convert.ToString(id));
			DataRow dr = dbutil.get_datarow(sql);

			// Fill in this form
			name.Value = (string) dr["og_name"];
			non_admins_can_use.Checked = Convert.ToBoolean((int)dr["og_non_admins_can_use"]);
			external_user.Checked = Convert.ToBoolean((int)dr["og_external_user"]);
			can_edit_sql.Checked = Convert.ToBoolean((int)dr["og_can_edit_sql"]);
			can_delete_bug.Checked = Convert.ToBoolean((int)dr["og_can_delete_bug"]);
			can_edit_and_delete_posts.Checked = Convert.ToBoolean((int)dr["og_can_edit_and_delete_posts"]);
			can_merge_bugs.Checked = Convert.ToBoolean((int)dr["og_can_merge_bugs"]);
			can_mass_edit_bugs.Checked = Convert.ToBoolean((int)dr["og_can_mass_edit_bugs"]);
			can_use_reports.Checked = Convert.ToBoolean((int)dr["og_can_use_reports"]);
			can_edit_reports.Checked = Convert.ToBoolean((int)dr["og_can_edit_reports"]);
			can_be_assigned_to.Checked = Convert.ToBoolean((int)dr["og_can_be_assigned_to"]);

			other_orgs.SelectedValue = Convert.ToString((int)dr["og_other_orgs_permission_level"]);

			project_field.SelectedValue = Convert.ToString((int)dr["og_project_field_permission_level"]);
			org_field.SelectedValue = Convert.ToString((int)dr["og_org_field_permission_level"]);
			category_field.SelectedValue = Convert.ToString((int)dr["og_category_field_permission_level"]);
			tags_field.SelectedValue = Convert.ToString((int)dr["og_tags_field_permission_level"]);
			priority_field.SelectedValue = Convert.ToString((int)dr["og_priority_field_permission_level"]);
			status_field.SelectedValue = Convert.ToString((int)dr["og_status_field_permission_level"]);
			assigned_to_field.SelectedValue = Convert.ToString((int)dr["og_assigned_to_field_permission_level"]);
			udf_field.SelectedValue = Convert.ToString((int)dr["og_udf_field_permission_level"]);

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
			sql = @"insert into orgs
			(og_name,
			og_non_admins_can_use,
			og_external_user,
			og_can_edit_sql,
			og_can_delete_bug,
			og_can_edit_and_delete_posts,
			og_can_merge_bugs,
			og_can_mass_edit_bugs,
			og_can_use_reports,
			og_can_edit_reports,
			og_can_be_assigned_to,
			og_other_orgs_permission_level,
			og_project_field_permission_level,
			og_org_field_permission_level,
			og_category_field_permission_level,
			og_tags_field_permission_level,
			og_priority_field_permission_level,
			og_status_field_permission_level,
			og_assigned_to_field_permission_level,
			og_udf_field_permission_level)
			values (N'$nam', $non,
			$ext, $ces, $cdb,
			$cep, $cmb, $cme,
			$cur, $cer, $cba, $other_orgs,
			$flp_project,
			$flp_org,
			$flp_category,
			$flp_tags,
			$flp_priority,
			$flp_status,
			$flp_assigned_to,
			$flp_udf)";
		}
		else // edit existing
		{

			sql = @"update orgs set
			og_name = N'$nam',
			og_non_admins_can_use = $non,
			og_external_user = $ext,
			og_can_edit_sql = $ces,
			og_can_delete_bug = $cdb,
			og_can_edit_and_delete_posts = $cep,
			og_can_merge_bugs = $cmb,
			og_can_mass_edit_bugs = $cme,
			og_can_use_reports = $cur,
			og_can_edit_reports = $cer,
			og_can_be_assigned_to = $cba,
			og_other_orgs_permission_level = $other_orgs,
			og_project_field_permission_level = $flp_project,
			og_org_field_permission_level = $flp_org,
			og_category_field_permission_level = $flp_category,
			og_tags_field_permission_level = $flp_tags,
			og_priority_field_permission_level = $flp_priority,
			og_status_field_permission_level = $flp_status,
			og_assigned_to_field_permission_level = $flp_assigned_to,
			og_udf_field_permission_level = $flp_udf
			where og_id = $og_id";

			sql = sql.Replace("$og_id", Convert.ToString(id));

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
		sql = sql.Replace("$other_orgs", other_orgs.SelectedValue);
		sql = sql.Replace("$flp_project", project_field.SelectedValue);
		sql = sql.Replace("$flp_org", org_field.SelectedValue);
		sql = sql.Replace("$flp_category", category_field.SelectedValue);
		sql = sql.Replace("$flp_tags", tags_field.SelectedValue);
		sql = sql.Replace("$flp_priority", priority_field.SelectedValue);
		sql = sql.Replace("$flp_status", status_field.SelectedValue);
		sql = sql.Replace("$flp_assigned_to", assigned_to_field.SelectedValue);
		sql = sql.Replace("$flp_udf", udf_field.SelectedValue);


		dbutil.execute_nonquery(sql);
		Server.Transfer ("orgs.aspx");

	}
	else
	{
		if (id == 0)  // insert new
		{
			msg.InnerText = "Organization was not created.";
		}
		else // edit existing
		{
			msg.InnerText = "Organization was not updated.";
		}

	}

}

</script>

<html>
<head>
<title id="titl" runat="server">btnet edit org</title>
<link rel="StyleSheet" href="btnet.css" type="text/css">
</head>
<body>
<% security.write_menu(Response, "admin"); %>


<div class=align><table border=0><tr><td>
<a href=orgs.aspx>back to organizations</a>
<form class=frm runat="server">
	<table border=0>

	<tr>
	<td class=lbl>Organization Name:</td>
	<td><input runat="server" type=text class=txt id="name" maxlength=30 size=30></td>
	<td runat="server" class=err id="name_err">&nbsp;</td>
	</tr>

	<tr>
	<td colspan=3>
	<br><br>
	<div class=smallnote style="width: 400px;">Can members of this organization view/edit bugs associated with other organizations?<br>
	</div>
	</td>
	</tr>

	<tr>
		<td class=lbl colspan=3>Permission level for bugs associated with other (or no) organizations<br>
		<asp:RadioButtonList RepeatDirection="Horizontal" id="other_orgs" runat="server">
			<asp:ListItem text="none"      value="0" ID="other_orgs0" runat="server"/>
			<asp:ListItem text="view only" value="1" ID="other_orgs1" runat="server"/>
			<asp:ListItem text="edit"      value="2" ID="other_orgs2" runat="server"/>
		</asp:RadioButtonList>


	<tr>
	<td colspan=3>
	&nbsp;
	</td>
	</tr>
    
    </table>
	<table border=0>


		<tr>
		<td><asp:checkbox runat="server" class=cb id="external_user"/></td>
		<td class=lbl>External users&nbsp;&nbsp; <span class=smallnote>(External users cannot view posts marked "Visible for internal usrs only")</span></td>
		<td>&nbsp</td>
		</tr>

		<tr>
		<td><asp:checkbox runat="server" class=cb id="can_be_assigned_to"/></td>
		<td class=lbl>Members of this org appear in "assigned to" dropdown in edit bug page</td>
		<td>&nbsp</td>
		</tr>

		<tr>
		<td><asp:checkbox runat="server" class=cb id="non_admins_can_use"/></td>
		<td class=lbl>Non-admin with permission to add users can add users to this org</td>
		<td>&nbsp</td>
		</tr>

	</table>

	<table border=0>


		<tr>
		<td colspan=3>
		<br><br>
		<div class=smallnote style="width: 400px;">Field level permissions<br>
		</div>
		</td>
		</tr>


		<tr>
		<td colspan=3>
		&nbsp;
		</td>
		</tr>

		<tr>
		<td>"Project" field permission
		<td colspan=2>
			<asp:RadioButtonList RepeatDirection="Horizontal" id="project_field" runat="server">
				<asp:ListItem text="none"      value="0" ID="project0" runat="server"/>
				<asp:ListItem text="view only" value="1" ID="project1" runat="server"/>
				<asp:ListItem text="edit"      value="2" ID="project2" runat="server"/>
			</asp:RadioButtonList>

		<tr>
		<td>"Organization" field permission
		<td colspan=2>
			<asp:RadioButtonList RepeatDirection="Horizontal" id="org_field" runat="server">
				<asp:ListItem text="none"      value="0" ID="org0" runat="server"/>
				<asp:ListItem text="view only" value="1" ID="org1" runat="server"/>
				<asp:ListItem text="edit"      value="2" ID="org2" runat="server"/>
			</asp:RadioButtonList>

		<tr>
		<td>"Category" field permission
		<td colspan=2>
			<asp:RadioButtonList RepeatDirection="Horizontal" id="category_field" runat="server">
				<asp:ListItem text="none"      value="0" ID="category0" runat="server"/>
				<asp:ListItem text="view only" value="1" ID="category1" runat="server"/>
				<asp:ListItem text="edit"      value="2" ID="category2" runat="server"/>
			</asp:RadioButtonList>

		<tr>
		<td>"Priority" field permission
		<td colspan=2>
			<asp:RadioButtonList RepeatDirection="Horizontal" id="priority_field" runat="server">
				<asp:ListItem text="none"      value="0" ID="priority0" runat="server"/>
				<asp:ListItem text="view only" value="1" ID="priority1" runat="server"/>
				<asp:ListItem text="edit"      value="2" ID="priority2" runat="server"/>
			</asp:RadioButtonList>

		<tr>
		<td>"Status" field permission
		<td colspan=2>
			<asp:RadioButtonList RepeatDirection="Horizontal" id="status_field" runat="server">
				<asp:ListItem text="none"      value="0" ID="status0" runat="server"/>
				<asp:ListItem text="view only" value="1" ID="status1" runat="server"/>
				<asp:ListItem text="edit"      value="2" ID="status2" runat="server"/>
			</asp:RadioButtonList>

		<tr>
		<td>"Assigned To" field permission
		<td colspan=2>
			<asp:RadioButtonList RepeatDirection="Horizontal" id="assigned_to_field" runat="server">
				<asp:ListItem text="none"      value="0" ID="assigned_to0" runat="server"/>
				<asp:ListItem text="view only" value="1" ID="assigned_to1" runat="server"/>
				<asp:ListItem text="edit"      value="2" ID="assigned_to2" runat="server"/>
			</asp:RadioButtonList>

		<tr>
		<td>User Defined Attribute field permission
		<td colspan=2>
			<asp:RadioButtonList RepeatDirection="Horizontal" id="udf_field" runat="server">
				<asp:ListItem text="none"      value="0" ID="udf0" runat="server"/>
				<asp:ListItem text="view only" value="1" ID="udf1" runat="server"/>
				<asp:ListItem text="edit"      value="2" ID="udf2" runat="server"/>
			</asp:RadioButtonList>

		<tr>
		<td>"Tags" field permission
		<td colspan=2>
			<asp:RadioButtonList RepeatDirection="Horizontal" id="tags_field" runat="server">
				<asp:ListItem text="none"      value="0" ID="tags0" runat="server"/>
				<asp:ListItem text="view only" value="1" ID="tags1" runat="server"/>
				<asp:ListItem text="edit"      value="2" ID="tags2" runat="server"/>
			</asp:RadioButtonList>

	</table>
	<table border=0>

		<tr>
		<td colspan=3>
		<br><br>
		<div class=smallnote style="width: 400px;">Use the following settings to control permissions for non-admins.<br>Admins have all permissions regardless of these settings.<br>
		</div>
		</td>
		</tr>


		<tr>
		<td colspan=3>
		&nbsp;
		</td>
		</tr>

		<tr>
		<td><asp:checkbox runat="server" class=cb id="can_edit_sql"/></td>
		<td class=lbl>Can edit sql and create/edit queries for everybody</td>
		<td>&nbsp</td>
		</tr>
		<tr>
		<td><asp:checkbox runat="server" class=cb id="can_delete_bug"/></td>
		<td class=lbl>Can delete bugs</td>
		<td>&nbsp</td>
		</tr>

		<tr>
		<td><asp:checkbox runat="server" class=cb id="can_edit_and_delete_posts"/></td>
		<td class=lbl>Can edit and delete comments and attachments</td>
		<td>&nbsp</td>
		</tr>
		<tr>
		<td><asp:checkbox runat="server" class=cb id="can_merge_bugs"/></td>
		<td class=lbl>Can merge two bugs into one</td>
		<td>&nbsp</td>
		</tr>
		<tr>
		<td><asp:checkbox runat="server" class=cb id="can_mass_edit_bugs"/></td>
		<td class=lbl>Can mass edit bugs on search page</td>
		<td>&nbsp</td>
		</tr>

		<tr>
		<td><asp:checkbox runat="server" class=cb id="can_use_reports"/></td>
		<td class=lbl>Can use reports</td>
		<td>&nbsp</td>
		</tr>
		<tr>
		<td><asp:checkbox runat="server" class=cb id="can_edit_reports"/></td>
		<td class=lbl>Can create/edit reports</td>
		<td>&nbsp</td>
		</tr>
	</table>

	<table border=0>


		<tr><td colspan=2 align=left>
		<span runat="server" class=err id="msg">&nbsp;</span>
		</td></tr>

		<tr>
		<td colspan=2 align=center>
		<input runat="server" class=btn type=submit id="sub" value="Create or Edit" OnServerClick="on_update">
		<td>&nbsp</td>
		</td>
		</tr>
		</td></tr>

	</table>

</form>
</td></tr></table></div>
<% Response.Write(Application["custom_footer"]); %></body>
</html>


