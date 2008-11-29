<%@ Page language="C#" validateRequest="false"%>
<%@ Register TagPrefix="FCKeditorV2" Namespace="FredCK.FCKeditorV2" Assembly="FredCK.FCKeditorV2" %>

<!--
Copyright 2002-2008 Corey Trager
Distributed under the terms of the GNU General Public License
-->
<!-- #include file = "inc.aspx" -->

<script language="C#" runat="server">

int id;
String sql;

DataSet ds_custom_cols;
DataRow dr;
DataTable dt_users = null;

DbUtil dbutil;
Security security;
SortedDictionary<string, string> hash_custom_cols = new SortedDictionary<string, string>();
SortedDictionary<string, string> hash_prev_custom_cols = new SortedDictionary<string, string>();

int permission_level;

bool images_inline = true;
bool history_inline = false;

bool status_changed = false;
bool assigned_to_changed = false;

void Page_Init (object sender, EventArgs e) {ViewStateUserKey = Session.SessionID;}


///////////////////////////////////////////////////////////////////////
void Page_Load(Object sender, EventArgs e)
{

	btnet.Util.do_not_cache(Response);
	dbutil = new DbUtil();
	security = new Security();
	security.check_security(dbutil, HttpContext.Current, Security.ANY_USER_OK);

	fckeComment.BasePath = @"fckeditor/";
	fckeComment.ToolbarSet = "BugTracker";

	set_msg("");
	set_custom_field_msg("");


	if (security.user.use_fckeditor)
	{
		fckeComment.Visible = true;
		comment.Visible = false;
	}
	else
	{
	    fckeComment.Visible = false;
		comment.Visible = true;
	}

	string string_bugid = Request["id"];
	if (string_bugid == null || string_bugid == "0" || (string_bugid != "0" && clone_ignore_bugid.Value == "1"))
	{
		bugid_label.InnerHtml = "Description:&nbsp;";
		id = 0;
	}
	else
	{
		bugid_label.Visible = true;
		bugid_label.InnerHtml = btnet.Util.capitalize_first_letter(btnet.Util.get_setting("SingularBugLabel","bug")) + " ID:&nbsp;";
		if (btnet.Util.is_int(string_bugid))
		{
			id = Convert.ToInt32(string_bugid);

			HttpCookie cookie = Request.Cookies["images_inline"];
			if (cookie == null || cookie.Value == "0")
			{
				images_inline = false;
			}
			else
			{
				images_inline = true;
			}

			cookie = Request.Cookies["history_inline"];
			if (cookie == null || cookie.Value == "0")
			{
				history_inline = false;
			}
			else
			{
				history_inline = true;
			}

		}
		else
		{
			// Display an error because the bugid must be an integer

			Response.Write ("<link rel=StyleSheet href=btnet.css type=text/css>");
			security.write_menu(Response, btnet.Util.get_setting("PluralBugLabel","bugs"));
			Response.Write("<p>&nbsp;</p><div class=align>");
			Response.Write("<div class=err>Error: ");
			Response.Write(btnet.Util.capitalize_first_letter(btnet.Util.get_setting("SingularBugLabel","bug")));
			Response.Write(" ID must be an integer.</div>");
			Response.Write("<p><a href=bugs.aspx>View ");
			Response.Write(btnet.Util.get_setting("PluralBugLabel","bugs"));
			Response.Write("</a>");
			Response.End();
		}
	}


	// get list of custom fields
	ds_custom_cols = btnet.Util.get_custom_columns(dbutil);

	if (security.user.external_user || btnet.Util.get_setting("EnableInternalOnlyPosts","0") == "0")
	{
		internal_only.Visible = false;
		internal_only_label.Visible = false;
	}


	if (!IsPostBack)
	{

		// First time in

		// Add or edit?

		if (id == 0)
		{
			sub.Value = "Create";
		}

		if (btnet.Util.get_setting("DisplayAnotherButtonInEditBugPage","0") == "1")
		{
			if (id == 0)
			{
				sub2.Value = "Create";
			}
		}

		if (id == 0)  // prepare the page for adding a new bug
		{
            load_dropdowns(null, security.user);

            titl.InnerText = btnet.Util.get_setting("AppTitle","BugTracker.NET") + " - Add New ";
			titl.InnerText += btnet.Util.capitalize_first_letter(btnet.Util.get_setting("SingularBugLabel","bug"));

			if (security.user.adds_not_allowed)
			{
				display_bug_not_found(id);
			}


			sql = "\nselect top 1 pj_id from projects where pj_default = 1 order by pj_name;"; // 0
			sql += "\nselect top 1 ct_id from categories where ct_default = 1 order by ct_name;";  // 1
			sql += "\nselect top 1 pr_id from priorities where pr_default = 1 order by pr_name;"; // 2
			sql += "\nselect top 1 st_id from statuses where st_default = 1 order by st_name;"; // 3
			sql += "\nselect top 1 udf_id from user_defined_attribute where udf_default = 1 order by udf_name;"; // 4

			DataSet ds_defaults = dbutil.get_dataset(sql);

			string default_value;

			load_project_and_user_dropdowns(ds_defaults.Tables[0]);


			// org
			default_value = Convert.ToString((int)security.user.org);
			foreach (ListItem li in org.Items)
			{
				if (li.Value == default_value)
				{
					li.Selected = true;
				}
				else
				{
					li.Selected = false;
				}
			}


			// category
			if (ds_defaults.Tables[1].Rows.Count > 0)
			{
				default_value = Convert.ToString((int) ds_defaults.Tables[1].Rows[0][0]);
			}
			else
			{
				default_value = "0";
			}
			foreach (ListItem li in category.Items)
			{
				if (li.Value == default_value)
				{
					li.Selected = true;
				}
				else
				{
					li.Selected = false;
				}
			}


			// priority
			if (ds_defaults.Tables[2].Rows.Count > 0)
			{
				default_value = Convert.ToString((int) ds_defaults.Tables[2].Rows[0][0]);
			}
			else
			{
				default_value = "0";
			}
			foreach (ListItem li in priority.Items)
			{
				if (li.Value == default_value)
				{
					li.Selected = true;
				}
				else
				{
					li.Selected = false;
				}
			}


			// status
			if (ds_defaults.Tables[3].Rows.Count > 0)
			{
				default_value = Convert.ToString((int) ds_defaults.Tables[3].Rows[0][0]);
			}
			else
			{
				default_value = "0";
			}
			foreach (ListItem li in status.Items)
			{
				if (li.Value == default_value)
				{
					li.Selected = true;
				}
				else
				{
					li.Selected = false;
				}
			}


			// udf
			if (ds_defaults.Tables[4].Rows.Count > 0)
			{
				default_value = Convert.ToString((int) ds_defaults.Tables[4].Rows[0][0]);
			}
			else
			{
				default_value = "0";
			}
			foreach (ListItem li in udf.Items)
			{
				if (li.Value == default_value)
				{
					li.Selected = true;
				}
				else
				{
					li.Selected = false;
				}
			}

			foreach (DataRow drcc in ds_custom_cols.Tables[0].Rows)
			{
                string column_name = (string)drcc["name"];
                if (security.user.dict_custom_field_permission_level[column_name] != Security.PERMISSION_NONE)
                {
                    string defaultval = get_custom_col_default_value(drcc["default value"]);
                    hash_custom_cols.Add(column_name, defaultval);
                    hash_prev_custom_cols.Add(column_name, "");
                }
			}

			set_controls_field_permission(Security.PERMISSION_ALL);

		}
		else // prepare page for editing existing bug
		{

			// Get this entry's data from the db and fill in the form

			dr = btnet.Bug.get_bug_datarow(id, security, ds_custom_cols);
            Session["bug_datarow"] = dr;

            load_dropdowns(dr, security.user);

			if (dr == null)
			{
				display_bug_not_found(id);
			}

			// look at permission level and react accordingly
			permission_level = (int)dr["pu_permission_level"];

			if (permission_level == Security.PERMISSION_NONE)
			{
				Response.Write ("<link rel=StyleSheet href=btnet.css type=text/css>");
				security.write_menu(Response, btnet.Util.get_setting("PluralBugLabel","bugs"));
				Response.Write("<p>&nbsp;</p><div class=align>");
				Response.Write("<div class=err>You are not allowed to view this "
					+ btnet.Util.get_setting("SingularBugLabel","bug")
					+ "</div>");
				Response.Write("<p><a href=bugs.aspx>View "
					+ btnet.Util.capitalize_first_letter(btnet.Util.get_setting
					("PluralBugLabel","bugs")) + "</a>");
				Response.End();

			}

			foreach (DataRow drcc in ds_custom_cols.Tables[0].Rows)
			{
				string column_name = (string)drcc["name"];
                if (security.user.dict_custom_field_permission_level[column_name] != Security.PERMISSION_NONE)
                {
                    string val = btnet.Util.format_db_value(dr[column_name]);
                    hash_custom_cols.Add(column_name, val);
                    hash_prev_custom_cols.Add(column_name, val);
                }
			}

			bugid.InnerText = Convert.ToString((int) dr["id"]);

			// Fill in this form
			short_desc.Value = (string) dr["short_desc"];
			tags.Value = (string) dr["bg_tags"];
			titl.InnerText = btnet.Util.capitalize_first_letter(btnet.Util.get_setting("SingularBugLabel","bug"))
				+" ID " + Convert.ToString(dr["id"]) + " " + (string) dr["short_desc"];

			// reported by
			string s;
			s = "Created by ";
			s += btnet.PrintBug.format_email_username(
					true,
					Convert.ToInt32(dr["id"]),
                    permission_level,
					Convert.ToString(dr["reporter_email"]),
					Convert.ToString(dr["reporter"]),
					Convert.ToString(dr["reporter_fullname"]));
			s += " on ";
			s += btnet.Util.format_db_date_and_time (dr["reported_date"]);
			s += ", ";
			s += btnet.Util.how_long_ago((int)dr["seconds_ago"]);


			reported_by.InnerHtml = s;

			// select the dropdowns

			foreach (ListItem li in org.Items)
			{
				if (Convert.ToInt32(li.Value) == (int) dr["organization"])
				{
					li.Selected = true;
				}
				else
				{
					li.Selected = false;
				}
			}

			foreach (ListItem li in category.Items)
			{
				if (Convert.ToInt32(li.Value) == (int) dr["category"])
				{
					li.Selected = true;
				}
				else
				{
					li.Selected = false;
				}
			}

			foreach (ListItem li in priority.Items)
			{
				if (Convert.ToInt32(li.Value) == (int) dr["priority"])
				{
					li.Selected = true;
				}
				else
				{
					li.Selected = false;
				}
			}

			foreach (ListItem li in status.Items)
			{
				if (Convert.ToInt32(li.Value) == (int) dr["status"])
				{
					li.Selected = true;
				}
				else
				{
					li.Selected = false;
				}
			}

			foreach (ListItem li in udf.Items)
			{
				if (Convert.ToInt32(li.Value) == (int) dr["udf"])
				{
					li.Selected = true;
				}
				else
				{
					li.Selected = false;
				}
			}


			// save current values in previous, so that later we can write the audit trail when things change
			prev_short_desc.Value = (string) dr["short_desc"];
			prev_tags.Value = (string) dr["bg_tags"];
			prev_project.Value = Convert.ToString((int)dr["project"]);
			prev_project_name.Value = Convert.ToString(dr["current_project"]);
			prev_org.Value = Convert.ToString((int)dr["organization"]);
			prev_category.Value = Convert.ToString((int)dr["category"]);
			prev_priority.Value = Convert.ToString((int)dr["priority"]);
			prev_assigned_to.Value = Convert.ToString((int)dr["assigned_to_user"]);
			prev_assigned_to_username.Value = Convert.ToString(dr["assigned_to_username"]);
			prev_status.Value = Convert.ToString((int)dr["status"]);
			prev_udf.Value = Convert.ToString((int)dr["udf"]);
			prev_pcd1.Value = (string) dr["bg_project_custom_dropdown_value1"];
			prev_pcd2.Value = (string) dr["bg_project_custom_dropdown_value2"];
			prev_pcd3.Value = (string) dr["bg_project_custom_dropdown_value3"];


			load_project_and_user_dropdowns(null); // must come before set_controls_field_permission, after assigning to prev_ values


			set_controls_field_permission(permission_level);

			// save for next bug
			if (project.SelectedItem != null)
			{
				Session["project"] = project.SelectedItem.Value;
			}

			snapshot_timestamp.Value = Convert.ToDateTime(dr["snapshot_timestamp"]).ToString("yyyyMMdd HH\\:mm\\:ss\\:fff");

			string toggle_images_link = "<a href='javascript:toggle_images2("
				+ Convert.ToString(id) + ")'><span id=hideshow_images>"
				+ (images_inline ? "hide" : "show")
				+ " inline images"
				+ "</span></a>";
			toggle_images.InnerHtml = toggle_images_link;

			string toggle_history_link = "<a href='javascript:toggle_history2("
				+ Convert.ToString(id)	+ ")'><span id=hideshow_history>"
				+ (history_inline ? "hide" : "show")
				+ " change history"
				+ "</span></a>";
			toggle_history.InnerHtml = toggle_history_link;

			if (permission_level == Security.PERMISSION_ALL)
			{
				string clone_link = "<a class=warn href=\"javascript:clone()\" "
					+ " title='Create a copy of this item'><img src=paste_plain.png border=0 align=top>&nbsp;create copy</a>";
				clone.InnerHtml = clone_link;
			}


			if (permission_level != Security.PERMISSION_READONLY)
			{
				string attachment_link = "<img src=attach.gif align=top>&nbsp;<a href=\"javascript:open_popup_window('add_attachment.aspx','add attachment ',"
					+ Convert.ToString(id)
					+ ",600,300)\" title='Attach an image, document, or other file to this item'>add attachment</a>";
				attachment.InnerHtml = attachment_link;
			}


			if (permission_level != Security.PERMISSION_READONLY)
			{
				string send_email_link = "<a href='javascript:send_email("
					+ Convert.ToString(id)
					+ ")' title='Send an email about this item'><img src=email_edit.png border=0 align=top>&nbsp;send email</a>";
				send_email.InnerHtml = send_email_link;
			}

			if (permission_level != Security.PERMISSION_READONLY)
			{
				string subscribers_link = "<a target=_blank href=view_subscribers.aspx?id="
					+ Convert.ToString(id)
					+ " title='View users who have subscribed to email notifications for this item'><img src=telephone_edit.png border=0 align=top>&nbsp;subscribers</a>";
				subscribers.InnerHtml = subscribers_link;
			}


			int relationship_cnt = 0;
			if (id != 0)
			{
				relationship_cnt = (int) dr["relationship_cnt"];
			}
			string relationships_link = "<a target=_blank href=relationships.aspx?bgid="
				+ Convert.ToString(id)
				+ " title='Create a relationship between this item and another item'><img src=database_link.png border=0 align=top>&nbsp;relationships(<span id=relationship_cnt>" + relationship_cnt + "</span>)</a>";
			relationships.InnerHtml = relationships_link;

			if (btnet.Util.get_setting("EnableSubversionIntegration","0") == "1")
			{
				int revision_cnt = 0;
				if (id != 0)
				{
					revision_cnt = (int) dr["revision_cnt"];
				}
				string revisions_link = "<a target=_blank href=view_svn_file_revisions.aspx?id="
					+ Convert.ToString(id)
				+ " title='View Subversion revisions related to this item'><img src=accept.png border=0 align=top>&nbsp;svn revisions(<span id=revision_cnt>" + revision_cnt + "</span>)</a>";
				revisions.InnerHtml = revisions_link;
			}
			else
			{
				revisions.InnerHtml = "";
			}


			if (btnet.Util.get_setting("EnableTasks","0") == "1")
			{
				int task_cnt = 0;
				if (id != 0)
				{
					task_cnt = (int) dr["task_cnt"];
				}
				string tasks_link = "<a target=_blank href=tasks_frame.aspx?bugid="
					+ Convert.ToString(id)
				+ " title='View sub-tasks/time-tracking entries related to this item'><img src=clock.png border=0 align=top>&nbsp;tasks/time(<span id=task_cnt>" + task_cnt + "</span>)</a>";
				tasks.InnerHtml = tasks_link;
			}
			else
			{
				tasks.InnerHtml = "";
			}


			format_subcribe_cancel_link();


			print.InnerHtml = "<a target=_blank href=print_bug.aspx?id="
				+ Convert.ToString(id)
				+ " title='Display this item in a printer-friendly format'><img src=printer.png border=0 align=top>&nbsp;print</a>";


			// merge
			if (!security.user.is_guest) // don't allow delete
			{
				if (security.user.is_admin
				|| security.user.can_merge_bugs)
				{
					string merge_bug_link = "<a href=merge_bug.aspx?id="
						+ Convert.ToString(id)
						+ " title='Merge this item and another item together'><img src=database_refresh.png border=0 align=top>&nbsp;merge</a>";

					merge_bug.InnerHtml = merge_bug_link;
				}
			}

			// delete 
			if (!security.user.is_guest)
			{
				if (security.user.is_admin
				|| security.user.can_delete_bug)
				{
					string delete_bug_link = "<a href=delete_bug.aspx?id="
						+ Convert.ToString(id)
						+ " title='Delete this item'><img src=delete.png border=0 align=top>&nbsp;delete</a>";

					delete_bug.InnerHtml = delete_bug_link;
				}
			}

			// custom bug link
			if (btnet.Util.get_setting("CustomBugLinkLabel","") != "")
			{
				string custom_bug_link = "<a href="
					+ btnet.Util.get_setting("CustomBugLinkUrl","")
					+ "?bugid="
					+ Convert.ToString(id)
					+ "><img src=brick.png border=0 align=top>&nbsp;"
					+ btnet.Util.get_setting("CustomBugLinkLabel","")
					+ "</a>";

				custom.InnerHtml = custom_bug_link;
			}

			format_prev_next_bug();

		}

	}
	else // is PostBack
	{

		if (id != 0)
		{

			titl.InnerText = btnet.Util.capitalize_first_letter(btnet.Util.get_setting("SingularBugLabel","bug"))
				+ " ID " + Convert.ToString(id) + " " + short_desc.Value;

			permission_level = fetch_permission_level(project.SelectedItem.Value);

			if (project.SelectedItem.Value == prev_project.Value)
			{
				set_controls_field_permission(permission_level);
			}

		}

		// Fetch the values of the custom columns from the Request and stash them in a hash table.

		foreach (DataRow drcc in ds_custom_cols.Tables[0].Rows)
		{
            string column_name = (string)drcc["name"];
            
            if (security.user.dict_custom_field_permission_level[column_name] != Security.PERMISSION_NONE)
            {
                if (permission_level == Security.PERMISSION_ALL || id == 0)
			    {
				    hash_custom_cols.Add(column_name, Request[column_name]);
			    }
			    else
			    {
				    hash_custom_cols.Add(column_name, Request["prev_" + column_name]);
			    }
			    hash_prev_custom_cols.Add(column_name, Request["prev_" + column_name]);
            }
		}


		// needs to be reloaded if project changed
		load_project_and_user_dropdowns(null);

        Workflow.fill_status_dropdown((DataRow)Session["bug_datarow"], security.user, status.Items);

	}


}

///////////////////////////////////////////////////////////////////////
void load_project_and_user_dropdowns(DataTable project_default)
{

	if (!IsPostBack)
	{

		if (id == 0)
		{

			// get default values
			string initial_project = (string) Session["project"];

			// project
			if (security.user.forced_project != 0)
			{
				initial_project = Convert.ToString(security.user.forced_project);
			}

			if (initial_project != null && initial_project != "0")
			{
				foreach (ListItem li in project.Items)
				{
					if (li.Value == initial_project)
					{
						li.Selected = true;
					}
					else
					{
						li.Selected = false;
					}
				}
			}
			else
			{
				string default_value;
				if (project_default.Rows.Count > 0)
				{
					default_value = Convert.ToString((int)project_default.Rows[0][0]);
				}
				else
				{
					default_value = "0";
				}

				foreach (ListItem li in project.Items)
				{
					if (li.Value == default_value)
					{
						li.Selected = true;
					}
					else
					{
						li.Selected = false;
					}
				}
			}

		}
	}

	// It can happen that the project in the db is not listed in the dropdown, for example, when the project
	// had been active in the past but is no longer active.
	// Since that project IS the project associated with the bug, let's force it into the dropdown.

	if (id != 0) // if existing bug
	{

		if (prev_project.Value != "0")
		{
			// see if already in the dropdown.
			bool project_in_dropdown = false;
			foreach (ListItem li in project.Items)
			{
				if (li.Value == prev_project.Value)
				{
					project_in_dropdown = true;
					break;
				}
			}

			// Add to the list, even if permissions don't allow it now, because, in the past, they did allow it.
			if (!project_in_dropdown)
			{
				project.Items.Add(
					new ListItem(
						prev_project_name.Value,
						prev_project.Value));

			}
		}

		if (!IsPostBack)
		{
			foreach (ListItem li in project.Items)
			{
				if (li.Value == prev_project.Value)
				{
					li.Selected = true;
				}
				else
				{
					li.Selected = false;
				}
			}
		}
	}


	// What's selected now?   Save it before we refresh the dropdown.
	string current_value = "";

	if (IsPostBack)
	{
		current_value = assigned_to.SelectedItem.Value;
	}


	// Load the user dropdown, which changes per project
	// Only users explicitly allowed will be listed
    if (btnet.Util.get_setting("DefaultPermissionLevel", "2") == "0")
    {
        sql = @"
/* users this project */ select us_id, case when $fullnames then us_lastname + ', ' + us_firstname else us_username end us_username
from users
inner join orgs on us_org = og_id
where us_active = 1
and og_can_be_assigned_to = 1
and ($og_other_orgs_permission_level <> 0 or $og_id = og_id or og_external_user = 0)
and us_id in
    (select pu_user from project_user_xref
        where pu_project = $pj
	    and pu_permission_level <> 0)
order by us_username; ";
    }
    // Only users explictly DISallowed will be omitted
    else
    {
        sql = @"
/* users this project */ select us_id, case when $fullnames then us_lastname + ', ' + us_firstname else us_username end us_username
from users
inner join orgs on us_org = og_id
where us_active = 1
and og_can_be_assigned_to = 1
and ($og_other_orgs_permission_level <> 0 or $og_id = og_id or og_external_user = 0)
and us_id not in
    (select pu_user from project_user_xref
	    where pu_project = $pj
		and pu_permission_level = 0)
order by us_username; ";
    }
	
	if (btnet.Util.get_setting("UseFullNames","0") == "0")
	{
		// false condition
		sql = sql.Replace("$fullnames","0 = 1");
	}
	else
	{
		// true condition
		sql = sql.Replace("$fullnames","1 = 1");
	}

	if (project.SelectedItem != null)
	{
		sql = sql.Replace("$pj", project.SelectedItem.Value);
	}
	else
	{
		sql = sql.Replace("$pj", "0");
	}


    sql = sql.Replace("$og_id", Convert.ToString(security.user.org));
    sql = sql.Replace("$og_other_orgs_permission_level", Convert.ToString(security.user.other_orgs_permission_level));
    
	dt_users = dbutil.get_dataset(sql).Tables[0];

	assigned_to.DataSource = new DataView((DataTable)dt_users);
	assigned_to.DataTextField = "us_username";
	assigned_to.DataValueField = "us_id";
	assigned_to.DataBind();
	assigned_to.Items.Insert(0, new ListItem("[not assigned]", "0"));

	// It can happen that the user in the db is not listed in the dropdown, because of a subsequent change in permissions.
	// Since that user IS the user associated with the bug, let's force it into the dropdown.
	if (id != 0) // if existing bug
	{
		if (prev_assigned_to.Value != "0")
		{
			// see if already in the dropdown.
			bool user_in_dropdown = false;
			foreach (ListItem li in assigned_to.Items)
			{
				if (li.Value == prev_assigned_to.Value)
				{
					user_in_dropdown = true;
					break;
				}
			}

			// Add to the list, even if permissions don't allow it now, because, in the past, they did allow it.
			if (!user_in_dropdown)
			{
				assigned_to.Items.Insert(1,
					new ListItem(
						prev_assigned_to_username.Value,
						prev_assigned_to.Value));

			}
		}
	}

	// At this point, all the users we need are in the dropdown.
	// Now selected the selected.
	if (current_value == "")
	{
		current_value = prev_assigned_to.Value;
	}


	// Select the user.  We are either restoring the previous selection
	// or selecting what was in the database.
	if (current_value != "0")
	{
		foreach (ListItem li in assigned_to.Items)
		{
			if (li.Value == current_value)
			{
				li.Selected = true;
			}
			else
			{
				li.Selected = false;
			}
		}
	}

	// if nothing else is selected. select the default user for the project
	if (assigned_to.SelectedItem.Value == "0")
	{
		int project_default_user = 0;
		if (project.SelectedItem != null)
		{
			// get the default user of the project
			project_default_user = btnet.Util.get_default_user(Convert.ToInt32(project.SelectedItem.Value));

			if (project_default_user != 0)
			{
				foreach (ListItem li in assigned_to.Items)
				{
					if (Convert.ToInt32(li.Value) == project_default_user)
					{
						li.Selected = true;
					}
					else
					{
						li.Selected = false;
					}
				}
			}
		}
	}

}

///////////////////////////////////////////////////////////////////////
string get_custom_col_default_value(object o)
{
	string defaultval = Convert.ToString(o);

	// populate the sql default value of a custom field
	if (defaultval.Length > 2)
	{
		if (defaultval[0] == '('
		&& defaultval[defaultval.Length-1] == ')')
		{
			string defaultval_sql = "select " + defaultval.Substring(1,defaultval.Length-2);
			defaultval = Convert.ToString(dbutil.execute_scalar(defaultval_sql));
		}
	}

	return defaultval;
}

///////////////////////////////////////////////////////////////////////
void display_bug_not_found(int id)
{
	Response.Write ("<link rel=StyleSheet href=btnet.css type=text/css>");
	security.write_menu(Response, btnet.Util.get_setting("PluralBugLabel","bugs"));
	Response.Write("<p>&nbsp;</p><div class=align>");
	Response.Write("<div class=err>");
	Response.Write(btnet.Util.capitalize_first_letter(btnet.Util.get_setting("SingularBugLabel","bug")));
	Response.Write(" not found:&nbsp;" + Convert.ToString(id) + "</div>");
	Response.Write("<p><a href=bugs.aspx>View ");
	Response.Write(btnet.Util.get_setting("PluralBugLabel","bug"));
	Response.Write("</a>");
	Response.End();
}



///////////////////////////////////////////////////////////////////////
void format_subcribe_cancel_link()
{

	bool notification_email_enabled = (btnet.Util.get_setting("NotificationEmailEnabled","1") == "1");
	if (notification_email_enabled)
	{
		int subscribed;
		if (!IsPostBack)
		{
			subscribed = (int) dr["subscribed"];
		}
		else
		{
			// User might have changed bug to a project where we automatically subscribe
			// so be prepared to format the link even if this isn't the first time in.
			sql = "select count(1) from bug_subscriptions where bs_bug = $bg and bs_user = $us";
			sql = sql.Replace("$bg",Convert.ToString(id));
			sql = sql.Replace("$us",Convert.ToString(security.user.usid));
			subscribed = (int) dbutil.execute_scalar(sql);
		}

		if (security.user.is_guest) // wouldn't make sense to share an email address
		{
			subscriptions.InnerHtml = "";
		}
		else
		{

			string subscription_link = "<a id='notifications' title='Get or stop getting email notifications about changes to this item.'"
				+ " href='javascript:toggle_notifications("
				+ Convert.ToString(id)
				+ ")'><img src=telephone.png border=0 align=top>&nbsp;<span id='get_stop_notifications'>";

			if (subscribed > 0)
			{
				subscription_link += "stop notifications</span></a>";
			}
			else
			{
				subscription_link += "get notifications</span></a>";
			}

			subscriptions.InnerHtml = subscription_link;
		}
	}

}


///////////////////////////////////////////////////////////////////////
void set_org_field_permission(int bug_permission_level)
{
	// pick the most restrictive permission
	int perm_level = bug_permission_level < security.user.org_field_permission_level
		? bug_permission_level : security.user.org_field_permission_level;

	if (perm_level == Security.PERMISSION_NONE)
	{
		org_label.Visible = false;
		org.Visible = false;
		prev_org.Visible = false;
	}
	else if (perm_level == Security.PERMISSION_READONLY)
	{
		org.Visible = false;
		static_org.InnerText = org.SelectedItem.Text;
	}
	else // editable
	{
		static_org.Visible = false;
	}

}

///////////////////////////////////////////////////////////////////////
void set_shortdesc_field_permission()
{
	// turn on the spans to hold the data
	if (id != 0)
	{
		static_short_desc.Style["display"] = "block";
		short_desc.Visible = false;
	}

	static_short_desc.InnerText = short_desc.Value;

}


///////////////////////////////////////////////////////////////////////
void set_tags_field_permission(int bug_permission_level)
{

/// JUNK testing using cat permission
	// pick the most restrictive permission
	int perm_level = bug_permission_level < security.user.tags_field_permission_level
		? bug_permission_level : security.user.tags_field_permission_level;

	if (perm_level == Security.PERMISSION_NONE)
	{
		static_tags.Visible = false;
		tags_label.Visible = false;
		tags.Visible = false;
		tags_link.Visible = false;
		prev_tags.Visible = false;
		//tags_row.Style.display = "none";
	}
	else if (perm_level == Security.PERMISSION_READONLY)
	{
		if (id != 0)
		{
			tags.Visible = false;
			tags_link.Visible = false;
			static_tags.Visible = true;
			static_tags.InnerText = tags.Value;
		}
		else
		{
			tags_label.Visible = false;
			tags.Visible = false;
			tags_link.Visible = false;
		}
	}
	else // editable
	{
		static_tags.Visible = false;
	}

}


///////////////////////////////////////////////////////////////////////
void set_category_field_permission(int bug_permission_level)
{
	// pick the most restrictive permission
	int perm_level = bug_permission_level < security.user.category_field_permission_level
		? bug_permission_level : security.user.category_field_permission_level;

	if (perm_level == Security.PERMISSION_NONE)
	{
		category_label.Visible = false;
		category.Visible = false;
		prev_category.Visible = false;
	}
	else if (perm_level == Security.PERMISSION_READONLY)
	{
		category.Visible = false;
		static_category.InnerText = category.SelectedItem.Text;
	}
	else // editable
	{
		static_category.Visible = false;
	}

}

///////////////////////////////////////////////////////////////////////
void set_priority_field_permission(int bug_permission_level)
{
	// pick the most restrictive permission
	int perm_level = bug_permission_level < security.user.priority_field_permission_level
		? bug_permission_level : security.user.priority_field_permission_level;

	if (perm_level == Security.PERMISSION_NONE)
	{
		priority_label.Visible = false;
		priority.Visible = false;
		prev_priority.Visible = false;
	}
	else if (perm_level == Security.PERMISSION_READONLY)
	{
		priority.Visible = false;
		static_priority.InnerText = priority.SelectedItem.Text;
	}
	else // editable
	{
		static_priority.Visible = false;
	}

}

///////////////////////////////////////////////////////////////////////
void set_status_field_permission(int bug_permission_level)
{
	// pick the most restrictive permission
	int perm_level = bug_permission_level < security.user.status_field_permission_level
		? bug_permission_level : security.user.status_field_permission_level;

	if (perm_level == Security.PERMISSION_NONE)
	{
		status_label.Visible = false;
		status.Visible = false;
		prev_status.Visible = false;
	}
	else if (perm_level == Security.PERMISSION_READONLY)
	{
		status.Visible = false;
		static_status.InnerText = status.SelectedItem.Text;
	}
	else // editable
	{
		static_status.Visible = false;
	}
}


///////////////////////////////////////////////////////////////////////
void set_project_field_permission(int bug_permission_level)
{

	int perm_level = bug_permission_level < security.user.project_field_permission_level
		? bug_permission_level : security.user.project_field_permission_level;

	if (perm_level == Security.PERMISSION_NONE)
	{
		project_label.Visible = false;
		project.Visible = false;
		prev_project.Visible = false;
	}
	else if (perm_level == Security.PERMISSION_READONLY)
	{
		project.Visible = false;
		static_project.InnerText = project.SelectedItem.Text;
	}
	else
	{
		static_project.Visible = false;
	}
}


///////////////////////////////////////////////////////////////////////
void set_assigned_field_permission(int bug_permission_level)
{

	int perm_level = bug_permission_level < security.user.assigned_to_field_permission_level
		? bug_permission_level : security.user.assigned_to_field_permission_level;

	if (perm_level == Security.PERMISSION_NONE)
	{
		assigned_to_label.Visible = false;
		assigned_to.Visible = false;
		prev_assigned_to.Visible = false;
	}
	else if (perm_level == Security.PERMISSION_READONLY)
	{
		assigned_to.Visible = false;
		static_assigned_to.InnerText = assigned_to.SelectedItem.Text;
	}
}

///////////////////////////////////////////////////////////////////////
void set_udf_field_permission(int bug_permission_level)
{
	// pick the most restrictive permission
	int perm_level = bug_permission_level < security.user.udf_field_permission_level
		? bug_permission_level : security.user.udf_field_permission_level;

	if (perm_level == Security.PERMISSION_NONE)
	{
		udf_label.Visible = false;
		udf.Visible = false;
		prev_udf.Visible = false;
	}
	else if (perm_level == Security.PERMISSION_READONLY)
	{
		udf.Visible = false;
		static_udf.InnerText = udf.SelectedItem.Text;
	}
	else // editable
	{
		static_udf.Visible = false;
	}
}

///////////////////////////////////////////////////////////////////////
void set_controls_field_permission(int bug_permission_level)
{

	if (bug_permission_level == Security.PERMISSION_READONLY
	|| bug_permission_level == Security.PERMISSION_REPORTER)
	{
		// even turn off commenting updating for read only
		if (permission_level == Security.PERMISSION_READONLY)
		{
			sub.Disabled = true;
			sub.Visible = false;
			if (btnet.Util.get_setting("DisplayAnotherButtonInEditBugPage","0") == "1")
			{
				sub2.Disabled = true;
				sub2.Visible = false;
			}

			plus_label.Visible = false;
			comment_label.Visible = false;
			comment.Visible = false;
			fckeComment.Visible = false;
		}

		set_project_field_permission(Security.PERMISSION_READONLY);
		set_org_field_permission(Security.PERMISSION_READONLY);
		set_category_field_permission(Security.PERMISSION_READONLY);
		set_tags_field_permission(Security.PERMISSION_READONLY);
		set_priority_field_permission(Security.PERMISSION_READONLY);
		set_status_field_permission(Security.PERMISSION_READONLY);
		set_assigned_field_permission(Security.PERMISSION_READONLY);
		set_udf_field_permission(Security.PERMISSION_READONLY);
		set_shortdesc_field_permission();

		internal_only_label.Visible = false;
		internal_only.Visible = false;
	}
	else
	{
		// Call these functions so that the field level permissions can kick in
		if (security.user.forced_project != 0)
		{
			set_project_field_permission(Security.PERMISSION_READONLY);
		}
		else
		{
			set_project_field_permission(Security.PERMISSION_ALL);
		}

		if (security.user.other_orgs_permission_level == 0)
		{
			set_org_field_permission(Security.PERMISSION_READONLY);
		}
		else
		{
			set_org_field_permission(Security.PERMISSION_ALL);
		}
		set_category_field_permission(Security.PERMISSION_ALL);
		set_tags_field_permission(Security.PERMISSION_ALL);
		set_priority_field_permission(Security.PERMISSION_ALL);
		set_status_field_permission(Security.PERMISSION_ALL);
		set_assigned_field_permission(Security.PERMISSION_ALL);
		set_udf_field_permission(Security.PERMISSION_ALL);
	}

}



///////////////////////////////////////////////////////////////////////
void format_prev_next_bug()
{
	// for next/prev bug links
	DataView dv_bugs = (DataView) Session["bugs"];

	if (dv_bugs != null)
	{
		int prev_bug = 0;
		int next_bug = 0;
		bool this_bug_found = false;

		// read through the list of bugs looking for the one that matches this one
		foreach (DataRowView drv in dv_bugs)
		{
			if (this_bug_found)
			{
				// step 3 - get the next bug - we're done
				next_bug = (int) drv[1];
				break;
			}
			else if (id == (int) drv[1])
			{
				// step 2 - we found this - set switch
				this_bug_found = true;
			}
			else
			{
				// step 1 - save the previous just in case the next one IS this bug
				prev_bug = (int) drv[1];
			}
		}

		string prev_next_link = "";

		if (this_bug_found)
		{
			if (prev_bug != 0)
			{
				prev_next_link =
					"&nbsp;&nbsp;&nbsp;&nbsp;<a class=warn href=edit_bug.aspx?id="
					+ Convert.ToString(prev_bug)
					+ "><img src=arrow_up.png border=0 align=top>prev</a>";
			}
			else
			{
				prev_next_link = "&nbsp;&nbsp;&nbsp;&nbsp;<span class=gray_link>prev</span>";
			}

			if (next_bug != 0)
			{
				prev_next_link +=
					"&nbsp;&nbsp;&nbsp;&nbsp;<a class=warn href=edit_bug.aspx?id="
					+ Convert.ToString(next_bug)
					+ ">next<img src=arrow_down.png border=0 align=top></a>";

			}
			else
			{
				prev_next_link += "&nbsp;&nbsp;&nbsp;&nbsp;<span class=gray_link>next</span>";
			}

			prev_next.InnerHtml = prev_next_link;
		}

	}

}


///////////////////////////////////////////////////////////////////////
void load_dropdowns(DataRow dr, User user)
{

	// only show projects where user has permissions
	// 0
	sql = @"/* drop downs */ select pj_id, pj_name
		from projects
		left outer join project_user_xref on pj_id = pu_project
		and pu_user = $us
		where pj_active = 1
		and isnull(pu_permission_level,$dpl) not in (0, 1)
		order by pj_name;";

	sql = sql.Replace("$us",Convert.ToString(security.user.usid));
	sql = sql.Replace("$dpl", btnet.Util.get_setting("DefaultPermissionLevel","2"));

	// 1
	sql += "\nselect og_id, og_name from orgs order by og_name;";

	// 2
	sql += "\nselect ct_id, ct_name from categories order by ct_sort_seq, ct_name;";

	// 3
	sql += "\nselect pr_id, pr_name from priorities order by pr_sort_seq, pr_name;";

	// 4
	sql += "\nselect st_id, st_name from statuses order by st_sort_seq, st_name;";

	// 5
	sql += "\nselect udf_id, udf_name from user_defined_attribute order by udf_sort_seq, udf_name;";

	// do a batch of sql statements
	DataSet ds_dropdowns = dbutil.get_dataset(sql);

	project.DataSource = ds_dropdowns.Tables[0];
	project.DataTextField = "pj_name";
	project.DataValueField = "pj_id";
	project.DataBind();

	if (btnet.Util.get_setting("DefaultPermissionLevel","2") == "2")
	{
		project.Items.Insert(0, new ListItem("[no project]", "0"));
	}

	org.DataSource = ds_dropdowns.Tables[1];
	org.DataTextField = "og_name";
	org.DataValueField = "og_id";
	org.DataBind();
	org.Items.Insert(0, new ListItem("[no organization]", "0"));

	category.DataSource = ds_dropdowns.Tables[2];
	category.DataTextField = "ct_name";
	category.DataValueField = "ct_id";
	category.DataBind();
	category.Items.Insert(0, new ListItem("[no category]", "0"));

	priority.DataSource  = ds_dropdowns.Tables[3];
	priority.DataTextField = "pr_name";
	priority.DataValueField = "pr_id";
	priority.DataBind();
	priority.Items.Insert(0, new ListItem("[no priority]", "0"));

    // Make it easier to customize the list of statuses
    Workflow.fill_status_dropdown(dr, security.user, status.Items);

    if (status.Items.Count == 0)
    {
        status.DataSource = ds_dropdowns.Tables[4];
        status.DataTextField = "st_name";
        status.DataValueField = "st_id";
        status.DataBind();
        status.Items.Insert(0, new ListItem("[no status]", "0"));
    }

	udf.DataSource  = ds_dropdowns.Tables[5];
	udf.DataTextField = "udf_name";
	udf.DataValueField = "udf_id";
	udf.DataBind();
	udf.Items.Insert(0, new ListItem("[none]", "0"));


}

///////////////////////////////////////////////////////////////////////
string get_dropdown_text_from_value(DropDownList dropdown, string value)
{
	foreach (ListItem li in dropdown.Items)
	{
		if (li.Value == value)
		{
			return li.Text;
		}
	}

	return dropdown.Items[0].Text;
}


///////////////////////////////////////////////////////////////////////
bool did_something_change()
{
	bool something_changed = false;

	if (prev_short_desc.Value != short_desc.Value
	|| prev_tags.Value != tags.Value
	|| comment.Value.Length > 0
	|| fckeComment.Value.Length > 0
	|| clone_ignore_bugid.Value == "1"
	|| prev_project.Value != project.SelectedItem.Value
	|| prev_org.Value != org.SelectedItem.Value
	|| prev_category.Value != category.SelectedItem.Value
	|| prev_priority.Value != priority.SelectedItem.Value
	|| prev_assigned_to.Value != assigned_to.SelectedItem.Value
	|| prev_status.Value != status.SelectedItem.Value
	|| (btnet.Util.get_setting("ShowUserDefinedBugAttribute","1") == "1" &&
		prev_udf.Value != udf.SelectedItem.Value))
	{
		clone_ignore_bugid.Value = "0";
		something_changed = true;
	}


	if (!something_changed)
	{
        foreach (string column_name in hash_custom_cols.Keys)
		{
            string before = hash_prev_custom_cols[column_name];
            string after = hash_custom_cols[column_name];

			if (before != after)
			{
				something_changed = true;
				break;
			}

		}
	}


	if (!something_changed)
	{
		if ((Request["pcd1"] != null && prev_pcd1.Value != Request["pcd1"])
		|| (Request["pcd2"] != null && prev_pcd2.Value != Request["pcd2"])
		|| (Request["pcd3"] != null && prev_pcd3.Value != Request["pcd3"]))
		{
			something_changed = true;
		}
	}

	return something_changed;

}

///////////////////////////////////////////////////////////////////////
// returns true if there was a change
bool record_changes()
{

	string base_sql = @"
		insert into bug_posts
		(bp_bug, bp_user, bp_date, bp_comment, bp_type)
		values($id, $us, getdate(), N'$3', 'update')";

	base_sql = base_sql.Replace("$id", Convert.ToString(id));
	base_sql = base_sql.Replace("$us", Convert.ToString(security.user.usid));

	string from;
	sql = "";

	bool do_update = false;

	if (prev_short_desc.Value != short_desc.Value)
	{

		do_update = true;
		sql += base_sql.Replace(
			"$3",
			"changed desc from \""
			+ prev_short_desc.Value.Replace("'","''") + "\" to \""
			+ short_desc.Value.Replace("'","''") + "\"");

		prev_short_desc.Value = short_desc.Value;
	}

	if (prev_tags.Value != tags.Value)
	{

		do_update = true;
		sql += base_sql.Replace(
			"$3",
			"changed tags from \""
			+ prev_tags.Value.Replace("'","''") + "\" to \""
			+ tags.Value.Replace("'","''") + "\"");

		prev_tags.Value = tags.Value;

		if (btnet.Util.get_setting("EnableTags","0") == "1")
		{
            btnet.Tags.build_tag_index(Application);
		}

	}

	if (project.SelectedItem.Value != prev_project.Value)
	{

		// The "from" might not be in the dropdown anymore
		//from = get_dropdown_text_from_value(project, prev_project.Value);

		do_update = true;
		sql += base_sql.Replace(
			"$3",
			"changed project from \""
			+ prev_project_name.Value.Replace("'","''") + "\" to \""
			+ project.SelectedItem.Text.Replace("'","''") + "\"");

		prev_project.Value = project.SelectedItem.Value;
		prev_project_name.Value = project.SelectedItem.Text;

	}

	if (prev_org.Value != org.SelectedItem.Value)
	{

		from = get_dropdown_text_from_value(org, prev_org.Value);

		do_update = true;
		sql += base_sql.Replace(
			"$3",
			"changed organization from \""
			+ from.Replace("'","''") + "\" to \""
			+ org.SelectedItem.Text.Replace("'","''") + "\"");

		prev_org.Value = org.SelectedItem.Value;
	}

	if (prev_category.Value != category.SelectedItem.Value)
	{

		from = get_dropdown_text_from_value(category, prev_category.Value);

		do_update = true;
		sql += base_sql.Replace(
			"$3",
			"changed category from \""
			+ from.Replace("'","''") + "\" to \""
			+ category.SelectedItem.Text.Replace("'","''") + "\"");

		prev_category.Value = category.SelectedItem.Value;
	}

	if (prev_priority.Value != priority.SelectedItem.Value)
	{

		from = get_dropdown_text_from_value(priority, prev_priority.Value);

		do_update = true;
		sql += base_sql.Replace(
			"$3",
			"changed priority from \""
			+ from.Replace("'","''") + "\" to \""
			+ priority.SelectedItem.Text.Replace("'","''") + "\"");

		prev_priority.Value = priority.SelectedItem.Value;
	}


	if (prev_assigned_to.Value != assigned_to.SelectedItem.Value)
	{

		assigned_to_changed = true; // for notifications

		// The "from" might not be in the dropdown anymore...
		//from = get_dropdown_text_from_value(assigned_to, prev_assigned_to.Value);

		do_update = true;
		sql += base_sql.Replace(
			"$3",
			"changed assigned_to from \""
			+ prev_assigned_to_username.Value.Replace("'","''") + "\" to \""
			+ assigned_to.SelectedItem.Text.Replace("'","''") + "\"");

		prev_assigned_to.Value = assigned_to.SelectedItem.Value;
		prev_assigned_to_username.Value = assigned_to.SelectedItem.Text;
	}


	if (prev_status.Value != status.SelectedItem.Value)
	{
		status_changed = true; // for notifications

		from = get_dropdown_text_from_value(status, prev_status.Value);

		do_update = true;
		sql += base_sql.Replace(
			"$3",
			"changed status from \""
			+ from.Replace("'","''") + "\" to \""
			+ status.SelectedItem.Text.Replace("'","''") + "\"");

		prev_status.Value = status.SelectedItem.Value;
	}

	if (btnet.Util.get_setting("ShowUserDefinedBugAttribute","1") == "1")
	{
		if (prev_udf.Value != udf.SelectedItem.Value)
		{

			from = get_dropdown_text_from_value(udf, prev_udf.Value);

			do_update = true;
			sql += base_sql.Replace(
				"$3",
				"changed " 	+ btnet.Util.get_setting("UserDefinedBugAttributeName","YOUR ATTRIBUTE")
				+ " from \""
				+ from.Replace("'","''") + "\" to \""
				+ udf.SelectedItem.Text.Replace("'","''") + "\"");

			prev_udf.Value = udf.SelectedItem.Value;
		}
	}


	// Record changes in custom columns

	foreach (DataRow drcc in ds_custom_cols.Tables[0].Rows)
	{
		string column_name = (string)drcc["name"];

        if (security.user.dict_custom_field_permission_level[column_name] != Security.PERMISSION_ALL)
        {
            continue;
        }
        string before = hash_prev_custom_cols[column_name];
        string after = hash_custom_cols[column_name];

		if (before == "0" || before == "")
		{
			before = "";
		}
		if (after == "0" || after == "")
		{
			after = "";
		}

		if (before != after)
		{

			if ((string)drcc["dropdown type"] == "users")
			{

				string sql_get_username = "";
				if (before == "")
				{
					before = "";
				}
				else
				{
					sql_get_username = "select us_username from users where us_id = $1";
					before = (string) dbutil.execute_scalar(sql_get_username.Replace("$1", before));
				}


				if (after == "")
				{
					after = "";
				}
				else
				{
					sql_get_username = "select us_username from users where us_id = $1";
					after = (string) dbutil.execute_scalar(sql_get_username.Replace("$1", after));
				}
			}

			do_update = true;
			sql += base_sql.Replace(
				"$3",
                "changed " + column_name + " from \"" + before.Replace("'", "''") + "\" to \"" + after.Replace("'", "''") + "\"");

            hash_prev_custom_cols[column_name] = hash_custom_cols[column_name];
		}
	}


	// Handle project custom dropdowns
	if (Request["label_pcd1"] != null && Request["pcd1"] != null && prev_pcd1.Value != Request["pcd1"])
	{

		do_update = true;
		sql += base_sql.Replace(
			"$3",
			"changed "
			+ Request["label_pcd1"].Replace("'","''")
            + " from \"" + prev_pcd1.Value + "\" to \"" + Request["pcd1"].Replace("'","''") + "\"");

		prev_pcd1.Value = Request["pcd1"];
	}
    if (Request["label_pcd2"] != null && Request["pcd2"] != null && prev_pcd2.Value != Request["pcd2"].Replace("'","''"))
	{

		do_update = true;
		sql += base_sql.Replace(
			"$3",
			"changed "
			+ Request["label_pcd2"].Replace("'","''")
            + " from \"" + prev_pcd2.Value + "\" to \"" + Request["pcd2"].Replace("'","''") + "\"");

		prev_pcd2.Value = Request["pcd2"];
	}
	if (Request["label_pcd3"] != null && Request["pcd3"] != null && prev_pcd3.Value != Request["pcd3"])
	{

		do_update = true;
		sql += base_sql.Replace(
			"$3",
			"changed "
			+ Request["label_pcd3"].Replace("'","''")
            + " from \"" + prev_pcd3.Value + "\" to \"" + Request["pcd3"].Replace("'","''") + "\"");

		prev_pcd3.Value = Request["pcd3"];
	}


	if (do_update
	&& btnet.Util.get_setting("TrackBugHistory","1") == "1") // you might not want the debris to grow
	{
		dbutil.execute_nonquery(sql);
	}


	if (project.SelectedItem.Value != prev_project.Value)
	{
		permission_level = fetch_permission_level(project.SelectedItem.Value);
	}


    if (do_update && btnet.Util.get_setting("EnableLucene", "1") == "1")
    {
        MyLucene.update_lucene_index(id);
    }        
    
	// return true if something did change
	return do_update;
}

///////////////////////////////////////////////////////////////////////
int fetch_permission_level(string projectToCheck)
{

	// fetch the revised permission level
	sql = @"declare @permission_level int
		set @permission_level = -1
		select @permission_level = isnull(pu_permission_level,$dpl)
		from project_user_xref
		where pu_project = $pj
		and pu_user = $us
		if @permission_level = -1 set @permission_level = $dpl
		select @permission_level";

	sql = sql.Replace("$dpl", btnet.Util.get_setting("DefaultPermissionLevel","2"));
	sql = sql.Replace("$pj", projectToCheck);
	sql = sql.Replace("$us", Convert.ToString(security.user.usid));
	int pl = (int) dbutil.execute_scalar(sql);

	// reduce permissions for guest
	//if (security.user.is_guest && permission_level == Security.PERMISSION_ALL)
	//{
	//	pl = Security.PERMISSION_REPORTER;
	//}

	return pl;

}
///////////////////////////////////////////////////////////////////////
Boolean validate()
{

	Boolean good = true;
	if (short_desc.Value == "")
	{
		good = false;
		short_desc_err.InnerText = "Short Description is required.";
	}
	else
	{
		short_desc_err.InnerText = "";
	}

//	if (comment.Value.Length > 200000 || fckeComment.Value.Length > 200000)
//	{
//		good = false;
//		comment_err.InnerText = "Comment cannot be longer than 200,000 characters.";
//	}
//	else
//	{
//		comment_err.InnerText = "";
//	}

	if (!did_something_change())
	{
		return false;
	}


    // validate custom columns
	foreach (DataRow drcc in ds_custom_cols.Tables[0].Rows)
	{

		string name = (string) drcc["name"];

        if (security.user.dict_custom_field_permission_level[name] != Security.PERMISSION_ALL)
        {
            continue;
        }
        
		string val = Request[name];

		if (val == null) continue;

		val = val.Replace("'","''");

		// if a date was entered, convert to db format
		if (val.Length > 0)
		{
			string datatype = drcc["datatype"].ToString();

			if (datatype == "datetime")
			{
				try
				{
					DateTime.Parse(val, btnet.Util.get_culture_info());
				}
				catch (FormatException)
				{
					append_custom_field_msg("\"" + name + "\" not in a valid date format.<br>");
					good = false;
				}
			}
			else if (datatype == "int")
			{
				if (!btnet.Util.is_int(val))
				{
					append_custom_field_msg("\"" + name + "\" must be an integer.<br>");
					good = false;
				}

			}
			else if (datatype == "decimal")
			{
				//modified by CJU on jan 9 2008 : better support for french number styles
				//check that val string is a valid decimal value
				System.Globalization.CultureInfo ci = btnet.Util.get_culture_info( );
				decimal x;
				if( !Decimal.TryParse( val, System.Globalization.NumberStyles.Float, ci, out x ) )
				{
					append_custom_field_msg("\"" + name + "\" not in a valid decimal format.<br>");
					good = false;
				}

				// check if there are too many digits overall
				int xprec = Convert.ToInt32(drcc["xprec"]);
				string[] vals = val.Split( new string[] { ci.NumberFormat.NumberDecimalSeparator }, StringSplitOptions.None );
				int prec = (vals.Length == 1 ? vals[0].Length : vals[0].Length + vals[1].Length);
				if( prec > xprec )
				{
					append_custom_field_msg("\"" + name + "\" has too many digits.<br>");
					good = false;
				}

				// check if there are too many digits to left or right of decimal
				int xscale = Convert.ToInt32(drcc["xscale"]);
				if( vals.Length == 1 )
				{
					if (vals[0].Length > xprec - xscale)
					{
						append_custom_field_msg("\"" + name + "\" has more than "
							+ Convert.ToString(xprec - xscale) + " digits to the left of the decimal point.<br>");
						good = false;
					}
				}

				if( vals.Length > 1 )
				{
					if (vals[1].Length > xscale)
					{
						append_custom_field_msg("\"" + name + "\" has more than "
							+  Convert.ToString(xscale) + " digits to the right of the decimal point.<br>");
						good = false;
					}
				}
				//end modified by CJU on jan 9 2008
			}
		}
		else
		{
			int nullable = (int) drcc["isnullable"];
			if (nullable == 0)
			{
				append_custom_field_msg("\"" + name + "\" is required.<br>");
				good = false;
			}
		}
	}


	return good;
}


///////////////////////////////////////////////////////////////////////
void on_update (Object sender, EventArgs e)
{

	bool good = validate();

	// save for next bug
	Session["project"] = project.SelectedItem.Value;

	bool bug_fields_have_changed = false;
    bool bugpost_fields_have_changed = false;

	if (good)
	{
		string comment_formated;
        string comment_search;
		string commentType;


		if (security.user.use_fckeditor) {
		    comment_formated = btnet.Util.strip_dangerous_tags(fckeComment.Value);
            comment_search = btnet.Util.strip_html(fckeComment.Value);
		    commentType = "text/html";
		}
		else
		{
			comment_formated = HttpUtility.HtmlDecode(comment.Value);
            comment_search = comment_formated;
			commentType = "text/plain";
		}

		if (id == 0)  // insert new
		{

			string pcd1 = Request["pcd1"];
			string pcd2 = Request["pcd2"];
			string pcd3 = Request["pcd3"];


			if (pcd1 == null)
			{
				pcd1 = "";
			}
			if (pcd2 == null)
			{
				pcd2 = "";
			}
			if (pcd3 == null)
			{
				pcd3 = "";
			}

			pcd1 = pcd1.Replace("'","''");
			pcd2 = pcd2.Replace("'","''");
			pcd3 = pcd3.Replace("'","''");



			btnet.Bug.NewIds new_ids = btnet.Bug.insert_bug(
				short_desc.Value,
				security,
                tags.Value,
				Convert.ToInt32(project.SelectedItem.Value),
				Convert.ToInt32(org.SelectedItem.Value),
				Convert.ToInt32(category.SelectedItem.Value),
				Convert.ToInt32(priority.SelectedItem.Value),
				Convert.ToInt32(status.SelectedItem.Value),
				Convert.ToInt32(assigned_to.SelectedItem.Value),
				Convert.ToInt32(udf.SelectedItem.Value),
				pcd1,
				pcd2,
				pcd3,
				comment_formated,
                comment_search,
				null, // from
                null, // cc
				commentType,
				internal_only.Checked,
				hash_custom_cols,
                true); // send notifications

            if (tags.Value != "" && btnet.Util.get_setting("EnableTags", "0") == "1")
            {
                btnet.Tags.build_tag_index(Application);
            }

			id = new_ids.bugid;

            if (btnet.Util.get_setting("EnableLucene", "1") == "1")
            {
                MyLucene.update_lucene_index(id);
            }

			btnet.WhatsNew.add_news(id, short_desc.Value, "added", security);

			new_id.Value = Convert.ToString(id);
			set_msg(btnet.Util.capitalize_first_letter(btnet.Util.get_setting("SingularBugLabel","bug")) + " was created.");
			Response.Redirect("edit_bug.aspx?id=" + Convert.ToString(id));
			status_changed = true;

		}
		else // edit existing
		{
			{
				string new_project;
				if (project.SelectedItem.Value != prev_project.Value)
				{
					new_project = project.SelectedItem.Value;
					int permission_on_new_project = fetch_permission_level(new_project);
					if ((Security.PERMISSION_NONE == permission_on_new_project) || (Security.PERMISSION_READONLY == permission_on_new_project))
					{
						set_msg(btnet.Util.capitalize_first_letter(btnet.Util.get_setting("SingularBugLabel","bug")) + " was not updated. You do not have the necessary permissions to change this " + btnet.Util.get_setting("SingularBugLabel","bug") + " to the specified Project.");
						return;
					}
				}
				else
				{
					new_project = prev_project.Value;
				}

				sql = @"declare @now datetime
					declare @last_updated datetime
					select @last_updated = bg_last_updated_date from bugs where bg_id = $id
					if @last_updated > '$snapshot_datetime'
					begin
						-- signal that we did NOT do the update
						set @now = '$snapshot_datetime'
					end
					else
					begin
						-- signal that we DID do the update
						set @now = getdate()

						update bugs set
						bg_short_desc = N'$sd',
                        bg_tags = N'$tags',
						bg_project = $pj,
						bg_org = $og,
						bg_category = $ct,
						bg_priority = $pr,
						bg_assigned_to_user = $au,
						bg_status = $st,
						bg_last_updated_user = $lu,
						bg_last_updated_date = @now,
						bg_user_defined_attribute = $udf,
						bg_project_custom_dropdown_value1 = N'$pcd1',
						bg_project_custom_dropdown_value2 = N'$pcd2',
						bg_project_custom_dropdown_value3 = N'$pcd3'
						$custom_cols_placeholder
						where bg_id = $id
					end
					select @now";

				sql = sql.Replace("$sd", short_desc.Value.Replace("'","''"));
                sql = sql.Replace("$tags", tags.Value.Replace("'", "''"));
				sql = sql.Replace("$lu", Convert.ToString(security.user.usid));
				sql = sql.Replace("$id", Convert.ToString(id));
				sql = sql.Replace("$pj", new_project);
				sql = sql.Replace("$og", org.SelectedItem.Value);
				sql = sql.Replace("$ct", category.SelectedItem.Value);
				sql = sql.Replace("$pr", priority.SelectedItem.Value);
				sql = sql.Replace("$au", assigned_to.SelectedItem.Value);
				sql = sql.Replace("$st", status.SelectedItem.Value);
				sql = sql.Replace("$udf", udf.SelectedItem.Value);
				sql = sql.Replace("$snapshot_datetime", snapshot_timestamp.Value);

				string pcd1 = Request["pcd1"];
				string pcd2 = Request["pcd2"];
				string pcd3 = Request["pcd3"];

				if (pcd1 == null)
				{
					pcd1 = "";
				}
				if (pcd2 == null)
				{
					pcd2 = "";
				}
				if (pcd3 == null)
				{
					pcd3 = "";
				}

				sql = sql.Replace("$pcd1", pcd1.Replace("'","''"));
				sql = sql.Replace("$pcd2", pcd2.Replace("'","''"));
				sql = sql.Replace("$pcd3", pcd3.Replace("'","''"));

				if (ds_custom_cols.Tables[0].Rows.Count == 0 || permission_level != Security.PERMISSION_ALL)
				{
					sql = sql.Replace("$custom_cols_placeholder","");
				}
				else
				{
					string custom_cols_sql = "";

					foreach (DataRow drcc in ds_custom_cols.Tables[0].Rows)
					{
						
                        string column_name = (string) drcc["name"];

                        // skip if no permission to update
                        if (security.user.dict_custom_field_permission_level[column_name] != Security.PERMISSION_ALL)
                        {
                            continue;
                        }
                        
                        custom_cols_sql += ",[" + column_name + "]";
						custom_cols_sql += " = ";
						
						string datatype = (string) drcc["datatype"];
						
						string custom_col_val = btnet.Util.request_to_string_for_sql(
							Request[column_name], 
							datatype);
						
						custom_cols_sql += custom_col_val;
					}
					sql = sql.Replace("$custom_cols_placeholder", custom_cols_sql);
				}

				DateTime last_update_date = (DateTime) dbutil.execute_scalar(sql);

				btnet.WhatsNew.add_news(id, short_desc.Value, "updated", security);

				string date_from_db = last_update_date.ToString("yyyyMMdd HH\\:mm\\:ss\\:fff");
				string date_from_webpage = snapshot_timestamp.Value;

				if (date_from_db != date_from_webpage)
				{
					snapshot_timestamp.Value = date_from_db;
					btnet.Bug.auto_subscribe(id);
					format_subcribe_cancel_link();
                    bug_fields_have_changed = record_changes();
				}
				else
				{
					set_msg(btnet.Util.capitalize_first_letter(btnet.Util.get_setting("SingularBugLabel","bug"))
						+ " was NOT updated.<br>"
						+ " Somebody changed it while you were editing it.<br>"
						+ " Click <a href=edit_bug.aspx?id="
						+ Convert.ToString(id)
						+ ">[here]</a> to refresh the page and discard your changes.<br>");
					return;
				}
			} // permission_level = 3 or not

            bugpost_fields_have_changed = (btnet.Bug.insert_comment(
                id,
                security.user.usid,
                comment_formated,
                comment_search,
                null, // from
                null, // cc
                commentType,
                internal_only.Checked) != 0);

			if (bug_fields_have_changed || (bugpost_fields_have_changed && !internal_only.Checked))
			{
				btnet.Bug.send_notifications(btnet.Bug.UPDATE,	id,	security, 0,
					status_changed,
					assigned_to_changed,
					Convert.ToInt32(assigned_to.SelectedItem.Value));
			}

			set_msg(btnet.Util.capitalize_first_letter(btnet.Util.get_setting("SingularBugLabel","bug")) + " was updated.");

			comment.Value = "";
			fckeComment.Value = "";

			set_controls_field_permission(permission_level);

            // GC: 16-Feb-2008: Bug fix to allow the Status drop down to be reloaded if there has been a change
            if (status_changed && Session["bug_datarow"] != null)
            {
                DataRow bug;

                bug = (DataRow) Session["bug_datarow"];
                bug["status"] = int.Parse(status.SelectedItem.Value);
                bug["status_name"] = status.SelectedItem.Text;

                Workflow.fill_status_dropdown(bug, security.user, status.Items);
            }
		} // edit existing or not

	}
	else
	{
		if (id == 0)  // insert new
		{
			set_msg(btnet.Util.capitalize_first_letter(btnet.Util.get_setting("SingularBugLabel","bug")) + " was not created.");
		}
		else // edit existing
		{
			set_msg(btnet.Util.capitalize_first_letter(btnet.Util.get_setting("SingularBugLabel","bug")) + " was not updated.");
		}
	}
}

///////////////////////////////////////////////////////////////////////
void set_msg(string s)
{
	msg.InnerHtml = s;
	if (btnet.Util.get_setting("DisplayAnotherButtonInEditBugPage","0") == "1")
	{
		msg2.InnerHtml = s;
	}
}

///////////////////////////////////////////////////////////////////////
void set_custom_field_msg(string s)
{
	custom_field_msg.InnerHtml = s;
	if (btnet.Util.get_setting("DisplayAnotherButtonInEditBugPage","0") == "1")
	{
		custom_field_msg2.InnerHtml = s;
	}
}

///////////////////////////////////////////////////////////////////////
void append_custom_field_msg(string s)
{
	custom_field_msg.InnerHtml += s;
	if (btnet.Util.get_setting("DisplayAnotherButtonInEditBugPage","0") == "1")
	{
		custom_field_msg2.InnerHtml += s;
	}
}

</script>

<html>
<head>
<title id=titl runat="server">add new</title>
<link rel="StyleSheet" href="btnet.css" type="text/css">
<link rel="StyleSheet" href="jquery/ui.datepicker.css" type="text/css">
<!-- use btnet_edit_bug.css to control positioning on edit_bug.asp.  use btnet_search.css to control position on search.aspx  -->
<link rel="StyleSheet" href="custom/btnet_edit_bug.css" type="text/css">
<script type="text/javascript" language="JavaScript" src="jquery/jquery-1.2.6.min.js"></script>
<script type="text/javascript" language="JavaScript" src="jquery/jquery-ui-1.6rc2.min.js"></script>
<script type="text/javascript" language="JavaScript" src="edit_bug.js"></script>

<script>
var this_bugid = <% Response.Write(Convert.ToString(id)); %>

$(document).ready(do_doc_ready);

function do_doc_ready()
{
	date_format = '<% Response.Write(btnet.Util.get_setting("DatepickerDateFormat","yy-mm-dd")); %>'
	$(".date").datepicker({dateFormat: date_format, duration: 'fast'})
	$(".date").change(mark_dirty)
	$(".warn").click(warn_if_dirty) 
}

function start_animation()
{

<% if (btnet.Util.get_setting("EnableNewPostAnimation","1") == "1") { %>

	color = 100
	
	if (navigator.userAgent.indexOf("MSIE") > 0)
		new_posts = getElementsByName_for_ie6_and_ie7("td","new_post") 
	else
		new_posts = document.getElementsByName("new_post") 
	
	
	new_posts_length = new_posts.length

	if (new_posts_length > 0)
	{
		
		timer = setInterval(timer_callback,5)
	}

<% } %>	
}

function disable_second_button()
{
<% if (btnet.Util.get_setting("DisplayAnotherButtonInEditBugPage","0") == "1") { %>
	el = get_el("sub");
	el.disabled = true;
<% } %>	

}

</script>

</head>

<body onload='on_body_load()' onunload='on_body_unload()'>
<% security.write_menu(Response, btnet.Util.get_setting("PluralBugLabel","bugs")); %>

<div class=align>

<% if (!security.user.adds_not_allowed) { %>
<a class=warn href="edit_bug.aspx?id=0"><img src=add.png border=0 align=top>&nbsp;add new <% Response.Write(btnet.Util.get_setting("SingularBugLabel","bug")); %></a>
&nbsp;&nbsp;&nbsp;&nbsp;
<% } %>
<span id="prev_next" runat="server">&nbsp;</span>


<br><br>

<table border=0 cellspacing=0 cellpadding=3>
<tr>

<td nowrap valign=top> <!-- links -->
	<div id="edit_bug_menu">
		<ul>
			<li id="clone" runat="server"/>
			<li id="print" runat="server" />
			<li id="merge_bug" runat="server" />
			<li id="delete_bug" runat="server" />
			<li id="revisions" runat="server" />
			<li id="subscribers" runat="server" />
			<li id="subscriptions" runat="server" />
			<li id="relationships" runat="server" />
			<li id="tasks" runat="server" />
			<li id="send_email" runat="server" />
			<li id="attachment" runat="server" />
			<li id="custom" runat="server" />
		</ul>
	</div>

<td nowrap valign=top> <!-- form -->

<div id="bugform_div">
<form class=frm runat="server">

	<% if (btnet.Util.get_setting("DisplayAnotherButtonInEditBugPage","0") == "1") { %>
		<div>
				<span runat="server" class=err id="custom_field_msg2">&nbsp;</span>
				<span runat="server" class=err id="msg2">&nbsp;</span>
		</div>
		<div style="text-align: center;">
			<input
				runat="server"
				class=btn
				type=submit
				id="sub2"
				onclick="disable_me()"
				value="Update"
				OnServerClick="on_update">
		</div>			
	<% } %>			
	<table border=0 cellpadding=3 cellspacing=0>
	<tr>
		<td nowrap valign=top>
			<span class=lbl id="bugid_label" runat="server"></span>
			<span runat="server" class="bugid" id="bugid"></span>&nbsp;

		<td valign=top>			

			<span class="short_desc_static" id="static_short_desc" runat="server" style='width:500px; display:none;'></span>


			<input runat="server" type=text class="short_desc_input" id="short_desc" maxlength="200"  
				onkeydown="count_chars('short_desc',200)" onkeyup="count_chars('short_desc',200)">
				&nbsp;&nbsp;&nbsp;
				<span runat="server" class=err id="short_desc_err"></span>
				
			<div class=smallnote id="short_desc_cnt">&nbsp;</div>

	</table>			
	<table width=90% border=0 cellpadding=3 cellspacing=0>
	<tr>
		<td nowrap>
			<span runat="server" id=reported_by></span>

		<% if (id == 0 || permission_level == Security.PERMISSION_ALL) { %>
		<td nowrap align=right id="presets" >Presets:
			<a title="Use previously saved settings for project, category, priority, etc..."
				href="javascript:get_presets()">use</a>
			&nbsp;/&nbsp;
			<a title="Save current settings for project, category, priority, etc., so that you can reuse later."
				href="javascript:set_presets()">save</a>
		<% } %>

	</table>

	<table border=0 cellpadding=0 cellspacing=4>

	<tr id="tags_row">
	    <td nowrap>
	        <span class=lbl id="tags_label" runat="server">Tags:&nbsp;</span>
	    </td>
		<td nowrap>
			<span class="stat" id="static_tags" runat="server"></span>
			<input runat="server" type=text class=txt id="tags" size="70" maxlength="80"  onkeydown="mark_dirty()" onkeyup="mark_dirty()">
			<span id="tags_link" runat="server">&nbsp;&nbsp;<a href='javascript:show_tags()'>tags</a></span>


	<tr id="row1">
		<td nowrap>
			<span class=lbl id="project_label" runat="server">Project:&nbsp;</span>
		<td nowrap>
			<span class="stat" id="static_project" runat="server"></span>

			<asp:DropDownList id="project" runat="server"
			AutoPostBack="True"></asp:DropDownList>

		<!--
		<td rowspan=100 bgcolor=yellow width=40>&nbsp;</td>
		<td rowspan=100 bgcolor=pink width=200>I'll put something here eventually...</td>
		-->
	<tr id="row2">
		<td nowrap>
			<span class=lbl id="org_label" runat="server">Organization:&nbsp;</span>
		<td nowrap>
			<span class="stat" id="static_org" runat="server"></span>
			<asp:DropDownList id="org" runat="server"></asp:DropDownList>

	<tr id="row3">
		<td nowrap>
			<span class=lbl id="category_label" runat="server">Category:&nbsp;</span>
		<td nowrap>
			<span class="stat" id="static_category" runat="server"></span>
			<asp:DropDownList id="category" runat="server"></asp:DropDownList>

	<tr id="row4">
		<td nowrap>
			<span class=lbl id="priority_label" runat="server">Priority:&nbsp;</span>
		<td nowrap>
			<span class="stat" id="static_priority" runat="server"></span>
			<asp:DropDownList id="priority" runat="server"></asp:DropDownList>

	<tr id="row5">
		<td nowrap>
			<span class=lbl id="assigned_to_label" runat="server">Assigned to:&nbsp;</span>
		<td nowrap>
			<span class="stat" id="static_assigned_to" runat="server"></span>
			<asp:DropDownList id="assigned_to" runat="server"></asp:DropDownList>

	<tr id="row6">
		<td nowrap>
			<span class=lbl id="status_label" runat="server">Status:&nbsp;</span>
		<td nowrap>
			<span class="stat" id="static_status" runat="server"></span>
			<asp:DropDownList id="status" runat="server"></asp:DropDownList>

<%
if (btnet.Util.get_setting("ShowUserDefinedBugAttribute","1") == "1")
{
%>
	<tr id="row7">
		<td nowrap>
			<span class=lbl id="udf_label" runat="server">
			<% Response.Write(btnet.Util.get_setting("UserDefinedBugAttributeName","YOUR ATTRIBUTE")); %>:&nbsp;</span>
		<td nowrap>
			<span class="stat" id="static_udf" runat="server"></span>
			<asp:DropDownList id="udf" runat="server">
			</asp:DropDownList>
<%
}

	int minTextAreaSize = int.Parse(btnet.Util.get_setting("TextAreaThreshold","100"));
	int maxTextAreaRows = int.Parse(btnet.Util.get_setting("MaxTextAreaRows","5"));

	// Create the custom column INPUT elements
	foreach (DataRow drcc in ds_custom_cols.Tables[0].Rows)
	{
        string column_name = (string) drcc["name"];

        int field_permission_level = security.user.dict_custom_field_permission_level[column_name];
        if (field_permission_level == Security.PERMISSION_NONE)
        {
            continue;
        }
        
        string field_id = column_name.Replace(" ", "");
        
		Response.Write ("\n<tr id=\"" + field_id + "_row\">");
		Response.Write ("<td nowrap><span id=\"" + field_id +  "_label\">");
        Response.Write(column_name);

		int permission_on_original = permission_level;

		if ((prev_project.Value != string.Empty)
		&& (project.SelectedItem == null || project.SelectedItem.Value != prev_project.Value))
		{
			permission_on_original = fetch_permission_level(prev_project.Value);
		}

		if (permission_on_original == Security.PERMISSION_READONLY
		|| permission_on_original == Security.PERMISSION_REPORTER)
		{
			Response.Write (":</span><td align=left width=600px>");
		}
		else
		{
			Response.Write (":</span><td align=left>");
		}

		//20040413 WWR - If a custom database field is over the defined character length, use a TextArea control
		int fieldLength = int.Parse(drcc["length"].ToString());

		if (permission_on_original == Security.PERMISSION_READONLY
        || field_permission_level == Security.PERMISSION_READONLY)
		{
            string text = hash_custom_cols[column_name];
			if ( fieldLength > minTextAreaSize && !string.IsNullOrEmpty(text))
			{
				// more readable if there is a lot of text
				Response.Write ("<div class='short_desc_static'  id=\"" + field_id +  "_static\">");
				Response.Write (text);
				Response.Write ("</div>");
			}
			else
			{
				Response.Write ("<span class='stat' id=\"" + field_id +  "_static\">");
				Response.Write (text);
				Response.Write ("</span>");
			}
		}  
		else
		{
			string dropdown_type = Convert.ToString(drcc["dropdown type"]);

			if ( fieldLength > minTextAreaSize
			&& dropdown_type != "normal"
			&& dropdown_type != "users")
			{
				Response.Write ("<textarea ");
				Response.Write (" onkeydown=\"return count_chars('" + field_id + "'," + fieldLength + ")\" ");
				Response.Write ("   onkeyup=\"return count_chars('" + field_id + "'," + fieldLength + ")\" ");
				Response.Write (" cols=\"" + minTextAreaSize + "\" rows=\"" + (((fieldLength/minTextAreaSize)>maxTextAreaRows) ? maxTextAreaRows : (fieldLength/minTextAreaSize)) + "\" " );
                Response.Write(" name=\"" + column_name + "\"");
				Response.Write (" id=\"" + field_id + "\" >");
                Response.Write(HttpUtility.HtmlEncode(hash_custom_cols[column_name]));
				Response.Write ("</textarea><div class=smallnote id=\"" + field_id + "_cnt\">&nbsp;</div>");
			}
			else
			{
				string dropdown_vals = Convert.ToString(drcc["vals"]);

				if (dropdown_type != "" || dropdown_vals != "")
				{
                    string selected_value = hash_custom_cols[column_name].Trim();

					Response.Write ("<select ");

					Response.Write (" id=\"" + field_id + "\"");
                    Response.Write(" name=\"" + column_name + "\"");
					Response.Write (">");

					if (dropdown_type != "users")
					{
						string[] options = btnet.Util.split_dropdown_vals(dropdown_vals);
						for (int j = 0; j < options.Length; j++)
						{
							Response.Write ("<option");


							if (HttpUtility.HtmlDecode(options[j]) == selected_value)
							{
								Response.Write (" selected ");
							}
							Response.Write (">");
							Response.Write (HttpUtility.HtmlDecode(options[j]));
							Response.Write ("</option>");
						}
					}
					else
					{
						Response.Write ("<option value=0>[not selected]</option>");

						DataView dv_users = new DataView(dt_users);
						foreach (DataRowView drv in dv_users)
						{
							string user_id = Convert.ToString(drv[0]);
							string user_name = Convert.ToString(drv[1]);

							Response.Write ("<option value=");
							Response.Write (user_id);

							if (user_id == selected_value)
							{
								Response.Write (" selected ");
							}
							Response.Write (">");
							Response.Write (user_name);
							Response.Write ("</option>");
						}
					}
					Response.Write ("</select>");
				}
				else
				{
					Response.Write ("<input type=text onkeydown=\"mark_dirty()\" onkeyup=\"mark_dirty()\" ");

					// match the size of the text field to the size of the database field
					string datatype = drcc["datatype"].ToString();
					
					if (datatype.IndexOf("char") > -1)
					{
						if (datatype == "nvarchar")
						{
							Response.Write (" size=" + Convert.ToString((Convert.ToInt32(drcc["length"]) / 2)));
							Response.Write (" maxlength=" + Convert.ToString((Convert.ToInt32(drcc["length"]) / 2)));
						}
						else
						{
							Response.Write (" size=" + drcc["length"]);
							Response.Write (" maxlength=" + drcc["length"]);
						}
					}

                    Response.Write(" name=\"" + column_name + "\"");
					Response.Write (" id=\"" + field_id + "\"");
					Response.Write (" value=\"");
                    Response.Write(hash_custom_cols[column_name]);

					if (datatype == "datetime")
					{
                        Response.Write("\" class='txt date'  >");
						Response.Write("<a style=\"font-size: 8pt;\"href=\"javascript:show_calendar('"
							+ field_id
							+ "');\">[select]</a>");
					}
					else
					{
                        Response.Write("\" class='txt' >");
    				}
				}
			}
		} // end if readonly or editable
		Response.Write ("</td></tr>");
	} // end loop through custom fields

	// create project custom dropdowns
	if (project.SelectedItem != null
	&& project.SelectedItem.Value != null
	&& project.SelectedItem.Value != "0")
	{
		sql = @"select
			isnull(pj_enable_custom_dropdown1,0) [pj_enable_custom_dropdown1],
			isnull(pj_enable_custom_dropdown2,0) [pj_enable_custom_dropdown2],
			isnull(pj_enable_custom_dropdown3,0) [pj_enable_custom_dropdown3],
			isnull(pj_custom_dropdown_label1,'') [pj_custom_dropdown_label1],
			isnull(pj_custom_dropdown_label2,'') [pj_custom_dropdown_label2],
			isnull(pj_custom_dropdown_label3,'') [pj_custom_dropdown_label3],
			isnull(pj_custom_dropdown_values1,'') [pj_custom_dropdown_values1],
			isnull(pj_custom_dropdown_values2,'') [pj_custom_dropdown_values2],
			isnull(pj_custom_dropdown_values3,'') [pj_custom_dropdown_values3]
			from projects where pj_id = $pj";

		sql = sql.Replace("$pj", project.SelectedItem.Value);

		DataRow project_dr = dbutil.get_datarow(sql);


		if (project_dr != null)
		{
			for (int i = 1; i < 4; i++)
			{
				if ((int)project_dr["pj_enable_custom_dropdown" + Convert.ToString(i)] == 1)
				{
					// GC: 20-Feb-08: Modified to add an ID to each custom row for CSS customisation
					Response.Write ("\n<tr id=\"pcdrow" + Convert.ToString(i) + "\"><td nowrap>");

					Response.Write ("<span id=label_pcd" + Convert.ToString(i) + ">");
					Response.Write (project_dr["pj_custom_dropdown_label" + Convert.ToString(i)]);
					Response.Write ("</span>");
					// End GC
					Response.Write ("<td nowrap>");


					int permission_on_original = permission_level;
					if ((prev_project.Value != string.Empty) && (project.SelectedItem.Value != prev_project.Value))
					{
						permission_on_original = fetch_permission_level(prev_project.Value);
					}
					if (permission_on_original == Security.PERMISSION_READONLY
					|| permission_on_original == Security.PERMISSION_REPORTER)
					{
						// GC: 20-Feb-08: Modified to add an ID to the SPAN as well for easier CSS customisation
						//Response.Write ("<span class="stat">");
						Response.Write ("<span class='stat' id=pcd" + Convert.ToString(i) + ">");
						if (IsPostBack)
						{
							Response.Write (Request["pcd" + Convert.ToString(i)]);
						}
						else
						{
							if (id !=0)
							{
								Response.Write (dr["bg_project_custom_dropdown_value" + Convert.ToString(i)]);
							}
						}
						Response.Write ("</span>");

					}
					else
					{

						// create a hidden area to carry the label

						Response.Write ("<input type=hidden");
						Response.Write (" name=label_pcd" + Convert.ToString(i));
						Response.Write (" value=\"");
						Response.Write (project_dr["pj_custom_dropdown_label" + Convert.ToString(i)]);
						Response.Write ("\">");

						// create a dropdown

						Response.Write ("<select");
						// GC: 20-Feb-08: Added an ID as well for easier CSS customisation
						Response.Write (" name=pcd" + Convert.ToString(i));
						Response.Write (" id=pcd" + Convert.ToString(i) + ">");
						string[] options = btnet.Util.split_dropdown_vals(
							(string)project_dr["pj_custom_dropdown_values" + Convert.ToString(i)]);

						string selected_value = "";

						if (IsPostBack)
						{
							selected_value = Request["pcd" + Convert.ToString(i)];
						}
						else
						{
							// first time viewing existing
							if (id != 0)
							{
								selected_value = (string) dr["bg_project_custom_dropdown_value" + Convert.ToString(i)];
							}
						}

						for (int j = 0; j < options.Length; j++)
						{
							Response.Write ("<option value=\"" + options[j] + "\"");

							//if (options[j] == selected_value)
							if (HttpUtility.HtmlDecode(options[j]) == selected_value)
							{
								Response.Write (" selected ");
							}
							Response.Write (">");
							Response.Write (options[j]);
						}

						Response.Write ("</select>");
					}
				}
			}
		} // if result set not null
	}

	%>

	</table>


	<table border=0 cellpadding=0 cellspacing=3 width=98%>

	<tr><td nowrap>
		<span id="plus_label" runat="server">
			<font size=0>
				<a href="#" onclick="<%= security.user.use_fckeditor ? "resize_iframe('fckeComment___Frame', 50);" : "resize_comment(10);" %>"><span id="toggle_link_plus">[+]</span></a>
				&nbsp;
				<a href="#" onclick="<%= security.user.use_fckeditor ? "resize_iframe('fckeComment___Frame', -50);" : "resize_comment(-10);" %>"><span id="toggle_link_minus">[-]</span></a>
			</font>
		</span>
		&nbsp;
		<span id="comment_label" runat="server">Comment:</span>
		
		<span class="smallnote" style="margin-left: 170px">
		<% 
		if (permission_level != Security.PERMISSION_READONLY)
		{		

			Response.Write ("Entering \"" 
				+ btnet.Util.get_setting("BugLinkMarker","bugid#") 
				+"999\" in comment creates link to id 999");
		} 
		%>		
		</span>
		<br>
		<textarea  id="comment" rows=5 cols=100 runat="server" class=txt onkeydown="mark_dirty()" onkeyup="mark_dirty()"></textarea>
		<FCKeditorV2:FCKeditor id="fckeComment" runat="server"></FCKeditorV2:FCKeditor>

	<tr><td  nowrap>
		<asp:checkbox runat="server" class=cb id="internal_only"/>
		<span runat="server" id="internal_only_label">Comment visible to internal users only</span>


	<tr><td nowrap align=left>
		<span runat="server" class=err id="custom_field_msg">&nbsp;</span>
		<span runat="server" class=err id="msg">&nbsp;</span>


	<tr><td nowrap align=center>
		<input
			runat="server"
			class=btn
			type=submit
			id="sub"
			onclick="disable_me()"
			value="Update"
			OnServerClick="on_update">

	</table>

	<input type=hidden id="new_id" runat="server" value="0">
	<input type=hidden id="prev_short_desc" runat="server">
	<input type=hidden id="prev_tags" runat="server">
	<input type=hidden id="prev_project" runat="server">
	<input type=hidden id="prev_project_name" runat="server">
	<input type=hidden id="prev_org" runat="server">
	<input type=hidden id="prev_category" runat="server">
	<input type=hidden id="prev_priority" runat="server">
	<input type=hidden id="prev_assigned_to" runat="server">
	<input type=hidden id="prev_assigned_to_username" runat="server">
	<input type=hidden id="prev_status" runat="server">
	<input type=hidden id="prev_udf" runat="server">
	<input type=hidden id="prev_pcd1" runat="server">
	<input type=hidden id="prev_pcd2" runat="server">
	<input type=hidden id="prev_pcd3" runat="server">
	<input type=hidden id="snapshot_timestamp" runat="server">
	<input type=hidden id="clone_ignore_bugid" runat="server" value="0">

<%

	// create the "Prev" fields for the custom columns so that we
	// can create an audit trail of their changes.

	foreach (string column_name in hash_custom_cols.Keys)
	{
		Response.Write ("<input type=hidden name=\"prev_");
        Response.Write(column_name);
		Response.Write ("\"");

		// output a date field according to the specified format
	    Response.Write (" value=\"");
		//modified by CJU on jan 9 2008
        Response.Write(hash_custom_cols[column_name]);
		//modified by CJU on jan 9 2008
		Response.Write ("\">\n");
	}

%>


</form>
</div> <!-- bug form div -->
</table>

<br>
<span id="toggle_images" runat="server"></span>
&nbsp;&nbsp;&nbsp;&nbsp;
<span id="toggle_history" runat="server"></span>
<br><br>

<div id="posts">

	<%
	// COMMENTS
	if (id != 0)
	{
		PrintBug.write_posts(
			Response,
			id,
			permission_level,
			true,
			images_inline,
			history_inline,
			security.user);
	}

	%>


</div>

</div>
<% Response.Write(Application["custom_footer"]); %></body>
</html>