<%@ Page language="C#" validateRequest="false"%>
<%@ Register TagPrefix="FCKeditorV2" Namespace="FredCK.FCKeditorV2" Assembly="FredCK.FCKeditorV2" %>

<!--
Copyright 2002-2007 Corey Trager
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
System.Collections.Hashtable hash_custom_cols;
System.Collections.Hashtable hash_prev_custom_cols;

int permission_level;

bool images_inline = true;
bool history_inline = false;

// make these non-global
bool status_changed = false;
bool assigned_to_changed = false;
int prev_assigned_to_user = 0;


///////////////////////////////////////////////////////////////////////
void Page_Load(Object sender, EventArgs e)
{

	btnet.Util.do_not_cache(Response);
	dbutil = new DbUtil();
	security = new Security();
	security.check_security(dbutil, HttpContext.Current, Security.ANY_USER_OK);

	hash_custom_cols = new System.Collections.Hashtable();
	hash_prev_custom_cols = new System.Collections.Hashtable();

	fckeComment.BasePath = @"fckeditor/";
	fckeComment.ToolbarSet = "BugTracker";

	msg.InnerText = "";
	custom_field_msg.InnerHtml = "";


	if (security.this_use_fckeditor)
	{
		fckeComment.Visible = true;
		comment.Visible = false;
	}
	else
	{
	    fckeComment.Visible = false;
		comment.Visible = true;
	}

	string var = Request.QueryString["id"];
	if (var == null)
	{
		id = 0;
	}
	else
	{
		if (btnet.Util.is_int(var))
		{
			id = Convert.ToInt32(var);

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

	if (security.this_external_user || btnet.Util.get_setting("EnableInternalOnlyPosts","0") == "0")
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
			comment.Rows = 12;
		}
		else
		{
			sub.Value = "Update";
		}


		load_drop_downs();


		if (id == 0)  // prepare the page for adding a new bug
		{
			titl.InnerText = btnet.Util.get_setting("AppTitle","BugTracker.NET") + " - Add New ";
			titl.InnerText += btnet.Util.capitalize_first_letter(btnet.Util.get_setting("SingularBugLabel","bug"));

			if (security.this_adds_not_allowed)
			{
				display_bug_not_found(id);
			}

			// get default values

			string initial_project = (string) Session["project"];

			sql = "\nselect top 1 pj_id from projects where pj_default = 1 order by pj_name;"; // 0
			sql += "\nselect top 1 ct_id from categories where ct_default = 1 order by ct_name;";  // 1
			sql += "\nselect top 1 pr_id from priorities where pr_default = 1 order by pr_name;"; // 2
			sql += "\nselect top 1 st_id from statuses where st_default = 1 order by st_name;"; // 3
			sql += "\nselect top 1 udf_id from user_defined_attribute where udf_default = 1 order by udf_name;"; // 4

			DataSet ds_defaults = dbutil.get_dataset(sql);

			string default_value;

			// project
			if (security.this_forced_project != 0)
			{
				initial_project = Convert.ToString(security.this_forced_project);
				set_project_to_readonly();
			}


			if (initial_project != null && initial_project != "0")
			{
				foreach (ListItem li in project.Items)
				{
					if (li.Value == initial_project)
					{
						li.Selected = true;
						current_project.InnerText = li.Text;
					}
					else
					{
						li.Selected = false;
					}
				}
			}
			else
			{
				if (ds_defaults.Tables[0].Rows.Count > 0)
				{
					default_value = Convert.ToString((int) ds_defaults.Tables[0].Rows[0][0]);
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

			// org

			if (security.this_other_orgs_permission_level == 0)
			{
				default_value = Convert.ToString((int)security.this_org);
			}
			else
			{
				if (ds_defaults.Tables[1].Rows.Count > 0)
				{
					default_value = Convert.ToString((int) ds_defaults.Tables[1].Rows[0][0]);
				}
				else
				{
					default_value = "0";
				}
			}

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

			if (security.this_other_orgs_permission_level == 0)
			{
				set_org_to_readonly();
			}


			// category
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

			foreach (ListItem li in assigned_to.Items)
			{
				if (li.Value == "[not assigned]")
				{
					li.Selected = true;
				}
				else
				{
					li.Selected = false;
				}
			}

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
				string defaultval = get_custom_col_default_value(drcc["default value"]);
				hash_custom_cols.Add((string)drcc["name"], defaultval);
				hash_prev_custom_cols.Add((string)drcc["name"], "");
			}


			// get default user here?

		}
		else // prepare page for editing existing bug
		{

			// Get this entry's data from the db and fill in the form


			dr = btnet.Bug.get_bug_datarow(id, security, ds_custom_cols);

			if (dr == null)
			{
				display_bug_not_found(id);
			}

			// look at permission level and react accordingly
			permission_level = (int)dr["pu_permission_level"];

			// reduce permissions for guest
			if (security.this_is_guest && permission_level == Security.PERMISSION_ALL)
			{
				permission_level = Security.PERMISSION_REPORTER;
			}

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
				hash_custom_cols.Add((string)drcc["name"], dr[(string)drcc["name"]]);
				hash_prev_custom_cols.Add((string)drcc["name"], dr[(string)drcc["name"]]);
			}

			bugid.InnerText = Convert.ToString((int) dr["id"]);

			// Fill in this form
			short_desc.Value = (string) dr["short_desc"];
			titl.InnerText = btnet.Util.capitalize_first_letter(btnet.Util.get_setting("SingularBugLabel","bug"))
				+" ID " + Convert.ToString(dr["id"]) + " " + (string) dr["short_desc"];

			current_project.InnerText = (string) dr["current_project"];

			assigned_to_username.InnerText = btnet.Util.format_username(
				(string) dr["assigned_to_username"],
				(string) dr["assigned_to_fullname"]);

			// reported by
			string s;
			s = "Created by <span class=static>" + btnet.Util.format_username(
				(string) dr["reporter"],
				(string) dr["reporter_fullname"]);

			s += "</span> on <span class=static>";
			s += btnet.Util.format_db_date (dr["reported_date"]);
			s += "</span>";

			reported_by.InnerHtml = s;

			// select the dropdowns

			foreach (ListItem li in project.Items)
			{
				if (Convert.ToInt32(li.Value) == (int) dr["project"])
				{
					li.Selected = true;
				}
				else
				{
					li.Selected = false;
				}
			}

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

			foreach (ListItem li in assigned_to.Items)
			{
				if (Convert.ToInt32(li.Value) == (int) dr["assigned_to_user"])
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

			if (permission_level == Security.PERMISSION_READONLY
			|| permission_level == Security.PERMISSION_REPORTER)
			{

				set_controls_to_readonly();

			}

			if (security.this_forced_project != 0)
			{
				set_project_to_readonly();
			}

			if (security.this_other_orgs_permission_level == 0)
			{
				set_org_to_readonly();
			}

			// save for next bug
			if (project.SelectedItem != null)
			{
				Session["project"] = project.SelectedItem.Value;
			}

			// save current values in previous, so that later we can write the audit trail when things change
			prev_short_desc.Value = (string) dr["short_desc"];
			prev_project.Value = Convert.ToString((int)dr["project"]);
			prev_org.Value = Convert.ToString((int)dr["organization"]);
			prev_category.Value = Convert.ToString((int)dr["category"]);
			prev_priority.Value = Convert.ToString((int)dr["priority"]);
			prev_assigned_to.Value = Convert.ToString((int)dr["assigned_to_user"]);
			prev_status.Value = Convert.ToString((int)dr["status"]);
			prev_udf.Value = Convert.ToString((int)dr["udf"]);
			prev_pcd1.Value = (string) dr["bg_project_custom_dropdown_value1"];
			prev_pcd2.Value = (string) dr["bg_project_custom_dropdown_value2"];
			prev_pcd3.Value = (string) dr["bg_project_custom_dropdown_value3"];

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

			if (permission_level != Security.PERMISSION_READONLY)
			{
				string attachment_link = "<a href=\"javascript:open_popup_window('add_attachment.aspx','add attachment ',"
					+ Convert.ToString(id)
					+ ",600,300)\" title='Attach an image, document, or other file to this item'>add attachment</a>";
				attachment.InnerHtml = attachment_link;
			}


			if (permission_level != Security.PERMISSION_READONLY)
			{
				string send_email_link = "<a href='javascript:send_email("
					+ Convert.ToString(id)
					+ ")' title='Send an email about this item'>send email</a>";
				send_email.InnerHtml = send_email_link;
			}

			string history_link = "<a target=_blank href=view_bug_history.aspx?id="
				+ Convert.ToString(id)
				+ " title='View history of changes to this item'>view history</a>";
			history.InnerHtml = history_link;

			if (permission_level != Security.PERMISSION_READONLY)
			{
				string subscribers_link = "<a target=_blank href=view_subscribers.aspx?id="
					+ Convert.ToString(id)
					+ " title='View users who have subscribed to email notifications for this item'>subscribers</a>";
				subscribers.InnerHtml = subscribers_link;
			}


			int relationship_cnt = 0;
			if (id != 0)
			{
				relationship_cnt = (int) dr["relationship_cnt"];
			}
			string relationships_link = "<a href=\"javascript:open_popup_window('relationships.aspx','relationships ',"
				+ Convert.ToString(id)
				+ ",750,550)\" title='Create a relationship between this item and another item'>relationships(<span id=relationship_cnt>" + relationship_cnt + "</span>)</a>";
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
				+ " title='View Subversion revisions related to this item'>svn revisions(<span id=revision_cnt>" + revision_cnt + "</span>)</a>";
				revisions.InnerHtml = revisions_link;
			}
			else
			{
				revisions.InnerHtml = "";
			}


			format_subcribe_cancel_link();


			print.InnerHtml = "<a target=_blank href=print_bug.aspx?id="
				+ Convert.ToString(id)
				+ " title='Display this item in a printer-friendly format'>print</a>";


			// edit bug
			if (security.this_is_admin
			|| security.this_can_merge_bugs)
			{
				string merge_bug_link = "<a href=merge_bug.aspx?id="
					+ Convert.ToString(id)
					+ " title='Merge this item and another item together'>merge</a>";

				merge_bug.InnerHtml = merge_bug_link;
			}

			// delete bug
			if (security.this_is_admin
			|| security.this_can_delete_bug)
			{
				string delete_bug_link = "<a href=delete_bug.aspx?id="
					+ Convert.ToString(id)
					+ " title='Delete this item'>delete</a>";

				delete_bug.InnerHtml = delete_bug_link;
			}


			// custom bug link
			if (btnet.Util.get_setting("CustomBugLinkLabel","") != "")
			{
				string custom_bug_link = "<a href="
					+ btnet.Util.get_setting("CustomBugLinkUrl","")
					+ "?bugid="
					+ Convert.ToString(id)
					+ ">"
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
				if (permission_level == Security.PERMISSION_READONLY
				|| permission_level == Security.PERMISSION_REPORTER)
				{
					set_controls_to_readonly();
				}
			}

		}

		// Fetch the values of the custom columns from the Request
		// and stash them in a hash table.

		foreach (DataRow drcc in ds_custom_cols.Tables[0].Rows)
		{
			if (permission_level == Security.PERMISSION_ALL || id == 0)
			{
				hash_custom_cols.Add(drcc["name"].ToString(), Request[(string)drcc["name"]]);
			}
			else
			{
				hash_custom_cols.Add(drcc["name"].ToString(), Request["prev_" + (string)drcc["name"]]);
			}
			hash_prev_custom_cols.Add(drcc["name"].ToString(), Request["prev_" + (string)drcc["name"]]);
		}
	}


	string current_assigned_to_selection;
	if (assigned_to.SelectedItem != null)
	{
		current_assigned_to_selection = assigned_to.SelectedItem.Value;
	}
	else
	{
		if (id != 0 && !IsPostBack)
		{
			current_assigned_to_selection =  Convert.ToString((int) dr["assigned_to_user"]);
		}
		else
		{
			current_assigned_to_selection = "0";
		}
	}


	// Only users explicitly allowed will be listed
	if (btnet.Util.get_setting("DefaultPermissionLevel","2") == "0")
	{
		sql = @"/* users this project */ select us_id, case when $fullnames then us_lastname + ', ' + us_firstname else us_username end us_username
			from users
			inner join orgs on us_org = og_id
			where us_active = 1
			and og_can_be_assigned_to = 1
			and us_id in
				(select pu_user from project_user_xref
				where pu_project = $pj
				and pu_permission_level <> 0)
			order by us_username; ";
	}
	// Only users explictly DISallowed will be omitted
	else
	{
		sql = @"/* users this project */ select us_id, case when $fullnames then us_lastname + ', ' + us_firstname else us_username end us_username
			from users
			inner join orgs on us_org = og_id
			where us_active = 1
			and og_can_be_assigned_to = 1
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

	if (dt_users == null)
	{
		dt_users = dbutil.get_dataset(sql).Tables[0];
	}
	assigned_to.DataSource = new DataView((DataTable)dt_users);
	assigned_to.DataTextField = "us_username";
	assigned_to.DataValueField = "us_id";
	assigned_to.DataBind();
	assigned_to.Items.Insert(0, new ListItem("[not assigned]", "0"));

	// automatically set to project's default user
	if (current_assigned_to_selection == "0")
	{
		if (project.SelectedItem != null)
		{
			current_assigned_to_selection = Convert.ToString(btnet.Util.get_default_user(Convert.ToInt32(project.SelectedItem.Value)));
		}
	}

	// redo selections
	foreach (ListItem li in assigned_to.Items)
	{
		if (li.Value == current_assigned_to_selection)
		{
			li.Selected = true;
			assigned_to_username.InnerText = li.Text;
		}
		else
		{
			li.Selected = false;
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
			sql = sql.Replace("$us",Convert.ToString(security.this_usid));
			subscribed = (int) dbutil.execute_scalar(sql);
		}

		if (security.this_is_guest)
		{
			subscriptions.InnerHtml = "";
		}
		else
		{
			string subscription_link = "<a id='notifications' title='Get or stop getting email notifications about changes to this item.'"
				+ " href='javascript:toggle_notifications("
				+ Convert.ToString(id)
				+ ")'><span id='get_stop_notifications'>";

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
void set_project_to_readonly()
{
	static_project.Style["display"] = "";
	change_project_label.Style["display"] = "none";
	project.Style["display"] = "none";
}

///////////////////////////////////////////////////////////////////////
void set_org_to_readonly()
{
	static_org.Style["display"] = "";
	org.Style["display"] = "none";
	static_org.InnerText = org.SelectedItem.Text;

}

///////////////////////////////////////////////////////////////////////
void set_shortdesc_to_readonly()
{
	// turn on the spans to hold the data
	if (id != 0)
	{
		static_short_desc.Style["display"] = "";
		short_desc.Style["display"] = "none";
	}

	static_short_desc.InnerText = short_desc.Value;

}


///////////////////////////////////////////////////////////////////////
void set_category_to_readonly()
{
	static_category.Style["display"] = "";
	category.Style["display"] = "none";
	static_category.InnerText = category.SelectedItem.Text;
}

///////////////////////////////////////////////////////////////////////
void set_priority_to_readonly()
{
	static_priority.Style["display"] = "";
	priority.Style["display"] = "none";
	static_priority.InnerText = priority.SelectedItem.Text;

}

///////////////////////////////////////////////////////////////////////
void set_status_to_readonly()
{
	static_status.Style["display"] = "";
	status.Style["display"] = "none";
	static_status.InnerText = status.SelectedItem.Text;
}


///////////////////////////////////////////////////////////////////////
void set_assigned_to_readonly()
{
	reassign_label.Style["display"] = "none";
	assigned_to.Style["display"] = "none";

}

///////////////////////////////////////////////////////////////////////
void set_udf_to_readonly()
{
	static_udf.Style["display"] = "";
	udf.Style["display"] = "none";
	static_udf.InnerText = udf.SelectedItem.Text;
}



///////////////////////////////////////////////////////////////////////
void set_controls_to_readonly()
{

	// even turn off commenting updating for read only
	if (permission_level == Security.PERMISSION_READONLY)
	{
		sub.Disabled = true;
		sub.Style["display"] = "none";
		plus_label.Style["display"] = "none";
		comment_label.Style["display"] = "none";
		comment.Style["display"] = "none";
		fckeComment.Visible = false;
	}

	set_project_to_readonly();
	set_org_to_readonly();
	set_category_to_readonly();
	set_priority_to_readonly();
	set_status_to_readonly();
	set_assigned_to_readonly();
	set_udf_to_readonly();
	set_shortdesc_to_readonly();

	internal_only_label.Visible = false;
	internal_only.Visible = false;

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
					"&nbsp;&nbsp;&nbsp;&nbsp;<a href=edit_bug.aspx?id="
					+ Convert.ToString(prev_bug)
					+ ">prev</a>";
			}
			else
			{
				prev_next_link = "&nbsp;&nbsp;&nbsp;&nbsp;<span class=gray_link>prev</span>";
			}

			if (next_bug != 0)
			{
				prev_next_link +=
					"&nbsp;&nbsp;&nbsp;&nbsp;<a href=edit_bug.aspx?id="
					+ Convert.ToString(next_bug)
					+ ">next</a>";

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
private void on_assigned_to_changed(object sender, System.EventArgs e)
{
   assigned_to_changed = true;
}

///////////////////////////////////////////////////////////////////////
void load_drop_downs()
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

	sql = sql.Replace("$us",Convert.ToString(security.this_usid));
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

	status.DataSource = ds_dropdowns.Tables[4];
	status.DataTextField = "st_name";
	status.DataValueField = "st_id";
	status.DataBind();
	status.Items.Insert(0, new ListItem("[no status]", "0"));

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
	|| comment.Value.Length > 0
	|| fckeComment.Value.Length > 0
	|| prev_project.Value != project.SelectedItem.Value
	|| prev_org.Value != org.SelectedItem.Value
	|| prev_category.Value != category.SelectedItem.Value
	|| prev_priority.Value != priority.SelectedItem.Value
	|| prev_assigned_to.Value != assigned_to.SelectedItem.Value
	|| prev_status.Value != status.SelectedItem.Value
	|| (btnet.Util.get_setting("ShowUserDefinedBugAttribute","1") == "1" &&
		prev_udf.Value != udf.SelectedItem.Value))
	{
		something_changed = true;
	}


	if (!something_changed)
	{
		foreach (DataRow drcc in ds_custom_cols.Tables[0].Rows)
		{
			string var = (string)drcc["name"];
			string before = hash_prev_custom_cols[var].ToString();
			string after = hash_custom_cols[var].ToString();

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
	base_sql = base_sql.Replace("$us", Convert.ToString(security.this_usid));

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

	if (project.SelectedItem.Value != prev_project.Value)
	{

		from = get_dropdown_text_from_value(project, prev_project.Value);

		do_update = true;
		sql += base_sql.Replace(
			"$3",
			"changed project from \""
			+ from.Replace("'","''") + "\" to \""
			+ project.SelectedItem.Text.Replace("'","''") + "\"");

		prev_project.Value = project.SelectedItem.Value;
		current_project.InnerText = project.SelectedItem.Text;

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

	if (assigned_to_changed)
	{

		from = get_dropdown_text_from_value(assigned_to, prev_assigned_to.Value);

		// not sure why i have to do this, but I do, otherwise
		// program writes an extra bug_history entry.
		if (assigned_to.SelectedItem.Text != from)
		{
			do_update = true;
			sql += base_sql.Replace(
				"$3",
				"changed assigned_to from \""
				+ from.Replace("'","''") + "\" to \""
				+ assigned_to.SelectedItem.Text.Replace("'","''") + "\"");

		}
		prev_assigned_to_user = Int32.Parse(prev_assigned_to.Value);
		prev_assigned_to.Value = assigned_to.SelectedItem.Value;
		assigned_to_username.InnerText = assigned_to.SelectedItem.Text;
	}

	if (prev_status.Value != status.SelectedItem.Value)
	{
		status_changed = true;

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


	// Handle custom columns

	foreach (DataRow drcc in ds_custom_cols.Tables[0].Rows)
	{
		string var = (string)drcc["name"];
		string before = hash_prev_custom_cols[var].ToString();
		string after = hash_custom_cols[var].ToString();

		if (before == null || before == "0" || before == "")
		{
			before = "";
		}
		if (after == null || after == "0" || after == "")
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
				"changed " + var + " from \"" + before.Replace("'","''") + "\" to \"" + after.Replace("'","''")  + "\"");

			hash_prev_custom_cols[(string)drcc["name"]]	= hash_custom_cols[(string)drcc["name"]];
		}
	}


	// Handle project custom dropdowns
	if (Request["pcd1"] != null && prev_pcd1.Value != Request["pcd1"])
	{

		do_update = true;
		sql += base_sql.Replace(
			"$3",
			"changed "
			+ Request["label_pcd1"].Replace("'","''")
            + " from \"" + prev_pcd1.Value + "\" to \"" + Request["pcd1"].Replace("'","''") + "\"");

		prev_pcd1.Value = Request["pcd1"];
	}
    if (Request["pcd2"] != null && prev_pcd2.Value != Request["pcd2"].Replace("'","''"))
	{

		do_update = true;
		sql += base_sql.Replace(
			"$3",
			"changed "
			+ Request["label_pcd2"].Replace("'","''")
            + " from \"" + prev_pcd2.Value + "\" to \"" + Request["pcd2"].Replace("'","''") + "\"");

		prev_pcd2.Value = Request["pcd2"];
	}
	if (Request["pcd3"] != null && prev_pcd3.Value != Request["pcd3"])
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
	&& btnet.Util.get_setting("TrackBugHistory","1") == "1")
	{
		dbutil.execute_nonquery(sql);
	}


	if (project.SelectedItem.Value != prev_project.Value)
	{
		permission_level = fetch_permission_level(project.SelectedItem.Value);
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
	sql = sql.Replace("$us", Convert.ToString(security.this_usid));
	int pl = (int) dbutil.execute_scalar(sql);

	// reduce permissions for guest
	if (security.this_is_guest && permission_level == Security.PERMISSION_ALL)
	{
		pl = Security.PERMISSION_REPORTER;
	}

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


	foreach (DataRow drcc in ds_custom_cols.Tables[0].Rows)
	{

		string name = drcc["name"].ToString();
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
					custom_field_msg.InnerHtml = "<br>\"" + name + "\" not in a valid date format.<br>";
					return false;
				}
			}
			else if (datatype == "int")
			{
				if (!btnet.Util.is_int(val))
				{
					custom_field_msg.InnerHtml = "<br>\"" + name + "\" must be an integer.<br>";
					return false;
				}

			}
			else if (datatype == "decimal")
			{
				try
				{
					Decimal.Parse(val, btnet.Util.get_culture_info());

					// check if there are too many digits overall
					int xprec = Convert.ToInt32(drcc["xprec"]);
					if (val.Replace(".","").Length > xprec)
					{
						custom_field_msg.InnerHtml = "<br>\"" + name + "\" has too many digits.<br>";
						return false;
					}

					// check if there are too many digits to left or right of decimal
					int xscale = Convert.ToInt32(drcc["xscale"]);
					int pos = val.IndexOf(".");
					if (pos > -1)
					{
						if (pos > xprec - xscale)
						{
							custom_field_msg.InnerHtml = "<br>\"" + name + "\" has too many digits to the left of the decimal point.<br>";
							return false;
						}

						if (val.Length-(pos+1) > xscale)
						{
							custom_field_msg.InnerHtml = "<br>\"" + name + "\" has too many digits to the right of the decimal point.<br>";
							return false;
						}
					}

				}
				catch (FormatException)
				{
					custom_field_msg.InnerHtml = "<br>\"" + name + "\" not in a valid decimal format.<br>";
					return false;
				}
			}
		}
		else
		{
			int nullable = (int) drcc["isnullable"];
			if (nullable == 0)
			{
				custom_field_msg.InnerHtml = "<br>\"" + name + "\" is required.<br>";
				return false;
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
		string commentText;
		string commentType;


		if (security.this_use_fckeditor) {
		    commentText = fckeComment.Value;
		    commentType = "text/html";
		}
		else
		{
			commentText = HttpUtility.HtmlDecode(comment.Value);
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
				Convert.ToInt32(project.SelectedItem.Value),
				Convert.ToInt32(org.SelectedItem.Value),
				Convert.ToInt32(category.SelectedItem.Value),
				Convert.ToInt32(priority.SelectedItem.Value),
				Convert.ToInt32(status.SelectedItem.Value),
				Convert.ToInt32(assigned_to.SelectedItem.Value),
				Convert.ToInt32(udf.SelectedItem.Value),
				Request["pcd1"],
				Request["pcd2"],
				Request["pcd3"],
				commentText,
				null,
				commentType,
				internal_only.Checked,
				hash_custom_cols,
                true); // send notifications

			id = new_ids.bugid;
			new_id.Value = Convert.ToString(id);
			msg.InnerText = btnet.Util.capitalize_first_letter(btnet.Util.get_setting("SingularBugLabel","bug")) + " was created.";
			sub.Value = "Update";
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
						msg.InnerText = btnet.Util.capitalize_first_letter(btnet.Util.get_setting("SingularBugLabel","bug")) + " was not updated. You do not have the necessary permissions to change this " + btnet.Util.get_setting("SingularBugLabel","bug") + " to the specified Project.";
						return;
					}
				}
				else
				{
					new_project = prev_project.Value;
				}

				string new_assigned_to;
				if (assigned_to_changed)
				{
					new_assigned_to = assigned_to.SelectedItem.Value;
				}
				else
				{
					new_assigned_to = prev_assigned_to.Value;
				}


				if (new_assigned_to == "0")
				{
					// assign to default user
					int default_user = btnet.Util.get_default_user(Convert.ToInt32(new_project));
					new_assigned_to = Convert.ToString(default_user);
					assigned_to_changed = true;

					foreach (ListItem li in assigned_to.Items)
					{
						if (Convert.ToInt32(li.Value) == default_user)
						{
							li.Selected = true;
							break;
						}
						else
						{
							li.Selected = false;
						}
					}
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
				sql = sql.Replace("$lu", Convert.ToString(security.this_usid));
				sql = sql.Replace("$id", Convert.ToString(id));
				sql = sql.Replace("$pj", new_project);
				sql = sql.Replace("$og", org.SelectedItem.Value);
				sql = sql.Replace("$ct", category.SelectedItem.Value);
				sql = sql.Replace("$pr", priority.SelectedItem.Value);
				sql = sql.Replace("$au", new_assigned_to);
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
						custom_cols_sql += ",[" + drcc["name"].ToString() + "]";
						custom_cols_sql += " = ";

						string val = Request[drcc["name"].ToString()].Replace("'","''");

						// if a date was entered, convert to db format
						if (val.Length > 0
						&& drcc["datatype"].ToString() == "datetime")
						{
							val = btnet.Util.format_local_date_into_db_format(val);
						}


						if (val.Length == 0)
						{
							custom_cols_sql += "null";
						}
						else
						{
							custom_cols_sql += "N'" + val + "'";
						}

					}
					sql = sql.Replace("$custom_cols_placeholder", custom_cols_sql);

				}


				DateTime last_update_date = (DateTime) dbutil.execute_scalar(sql);

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
					msg.InnerHtml = btnet.Util.capitalize_first_letter(btnet.Util.get_setting("SingularBugLabel","bug"))
						+ " was NOT updated.<br>"
						+ " Somebody changed it while you were editing it.<br>"
						+ " Click <a href=edit_bug.aspx?id="
						+ Convert.ToString(id)
						+ ">[here]</a> to refresh the page and discard your changes.<br>";
					return;
				}


			} // permission_level = 3 or not


            bugpost_fields_have_changed = (btnet.Bug.insert_comment(id, security.this_usid, commentText, null, commentType, internal_only.Checked) != 0);


			string result = "";
			if (bug_fields_have_changed || (bugpost_fields_have_changed && !internal_only.Checked))
			{
				result = btnet.Bug.send_notifications(btnet.Bug.UPDATE,	id,	security, 0,
					status_changed,
					assigned_to_changed,
					prev_assigned_to_user);
			}


			if (result == "")
			{
				msg.InnerText = btnet.Util.capitalize_first_letter(btnet.Util.get_setting("SingularBugLabel","bug")) + " was updated.";
			}
			else
			{
				msg.InnerHtml = result + "<br><br>" + btnet.Util.capitalize_first_letter(btnet.Util.get_setting("SingularBugLabel","bug")) + " was updated.";
			}

			comment.Value = "";
			fckeComment.Value = "";

			if (permission_level == Security.PERMISSION_READONLY
			|| permission_level == Security.PERMISSION_REPORTER)
			{
				set_controls_to_readonly();
			}

		} // edit existing or not
	}
	else
	{
		if (id == 0)  // insert new
		{
			msg.InnerText = btnet.Util.capitalize_first_letter(btnet.Util.get_setting("SingularBugLabel","bug")) + " was not created.";
		}
		else // edit existing
		{
			msg.InnerText = btnet.Util.capitalize_first_letter(btnet.Util.get_setting("SingularBugLabel","bug")) + " was not updated.";
		}
	}


}


</script>

<html>
<head>
<title id=titl runat="server">add new</title>
<link rel="StyleSheet" href="btnet.css" type="text/css">
<!-- use btnet_edit_bug.css to control positioning on edit_bug.asp.  use btnet_search.css to control position on search.aspx  -->
<link rel="StyleSheet" href="custom/btnet_edit_bug.css" type="text/css">
<script type="text/javascript" language="JavaScript" src="sortable.js"></script>
<script type="text/javascript" language="JavaScript" src="overlib_mini.js"></script>
<script type="text/javascript" language="JavaScript" src="calendar.js"></script>
<script type="text/javascript" language="JavaScript" src="edit_bug.js"></script>

<script>
var prompt = '<% Response.Write(btnet.Util.get_setting("PromptBeforeLeavingEditBugPage","0")); %>'
var this_bugid = <% Response.Write(Convert.ToString(id)); %>
</script>


</head>
<body onunload='on_body_unload()'>
<% security.write_menu(Response, btnet.Util.get_setting("PluralBugLabel","bugs")); %>

<div id="overDiv" style="position:absolute;visibility:hidden; z-index:1000;"></div>

<div class=align>

<% if (!security.this_adds_not_allowed) { %>
<a href=edit_bug.aspx?id=0>add new <% Response.Write(btnet.Util.get_setting("SingularBugLabel","bug")); %></a>
&nbsp;&nbsp;&nbsp;&nbsp;
<% } %>
<span id="prev_next" runat="server">&nbsp;</span>


<br><br>

<table border=0 cellspacing=0 cellpadding=3>
<tr>
<td nowrap valign=top> <!-- links -->
	<div id="edit_bug_menu">
		<ul>
			<li id="print" runat="server" />
			<li id="merge_bug" runat="server" />
			<li id="delete_bug" runat="server" />
			<li id="history" runat="server" />
			<li id="revisions" runat="server" />
			<li id="subscribers" runat="server" />
			<li id="subscriptions" runat="server" />
			<li id="relationships" runat="server" />
			<li id="send_email" runat="server" />
			<li id="attachment" runat="server" />
			<li id="custom" runat="server" />
		</ul>
	</div>

<td nowrap valign=top> <!-- form -->

<div id="bugform_div">
<form class=frm runat="server">
	<table border=0 cellpadding=3 cellspacing=0>

	<tr>
		<td nowrap colspan=2>
			<span class=lbl><% Response.Write(btnet.Util.capitalize_first_letter(btnet.Util.get_setting("SingularBugLabel","bug"))); %> ID:&nbsp;</span>
			<span runat="server" class=static id="bugid"></span>
			&nbsp;&nbsp;&nbsp;
			<span class=static id="static_short_desc" runat="server" style='width:500px; display: none;'></span>
			<input runat="server" type=text class=txt id="short_desc" size="100" maxlength="200">
			&nbsp;&nbsp;&nbsp;
			<span runat="server" class=err id="short_desc_err">&nbsp;</span>

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

	<table border=0 cellpadding=3 cellspacing=0>

	<tr id="row1">
		<td nowrap>
			<span class=lbl id="project_label">Project:&nbsp;</span>
		<td nowrap>
			<span class=static id="current_project" runat="server">[no project]</span>
			<span class=lbl id="static_project" runat="server" style='display: none;'></span>

			<span class=lbl id="change_project_label" runat="server">&nbsp;&nbsp;&nbsp;&nbsp;Change project:&nbsp;</span>

			<asp:DropDownList id="project" runat="server"
			AutoPostBack="True"></asp:DropDownList>

	<tr id="row2">
		<td nowrap>
			<span class=lbl id="org_label">Organization:&nbsp;</span>
		<td nowrap>
			<span class=static id="static_org" runat="server" style='display: none;'></span>

			<asp:DropDownList id="org" runat="server"></asp:DropDownList>


	<tr id="row3">
		<td nowrap>
			<span class=lbl id="category_label">Category:&nbsp;</span>
		<td nowrap>
			<span class=static id="static_category" runat="server" style='display: none;'></span>

			<asp:DropDownList id="category" runat="server"></asp:DropDownList>


	<tr id="row4">
		<td nowrap>
			<span class=lbl id="priority_label">Priority:&nbsp;</span>
		<td nowrap>
			<span class=static id="static_priority" runat="server" style='display: none;'></span>

			<asp:DropDownList id="priority" runat="server"></asp:DropDownList>

	<tr id="row5">
		<td nowrap>
			<span class=lbl id="assigned_to_label">Assigned to:&nbsp;</span>
		<td nowrap>
			<span class=static id="assigned_to_username" runat="server">[not assigned]</span>
			<span  runat="server" id="reassign_label" class=lbl>&nbsp;&nbsp;&nbsp;&nbsp;Re-assign:&nbsp;</span>

			<asp:DropDownList id="assigned_to" runat="server"
			OnSelectedIndexChanged="on_assigned_to_changed"> </asp:DropDownList>

	<tr id="row6">
		<td nowrap>
			<span class=lbl id="status_label">Status:&nbsp;</span>
		<td nowrap>
			<span class=static id="static_status" runat="server" style='display: none;'></span>
			<asp:DropDownList id="status" runat="server"></asp:DropDownList>


<%
if (btnet.Util.get_setting("ShowUserDefinedBugAttribute","1") == "1")
{
%>
	<tr id="row7">
		<td nowrap>
			<span class=lbl id="udf_label">
			<% Response.Write(btnet.Util.get_setting("UserDefinedBugAttributeName","YOUR ATTRIBUTE")); %>:&nbsp;</span>
		<td nowrap>
			<span class=static id="static_udf" runat="server" style='display: none;'></span>
			<asp:DropDownList id="udf" runat="server">
			</asp:DropDownList>
<%
}
%>


	<%

	int minTextAreaSize = int.Parse(btnet.Util.get_setting("TextAreaThreshold","100"));
	int maxTextAreaRows = int.Parse(btnet.Util.get_setting("MaxTextAreaRows","5"));

	// Create the custom column INPUT elements
	foreach (DataRow drcc in ds_custom_cols.Tables[0].Rows)
	{
		Response.Write ("\n<tr>");
		Response.Write ("<td nowrap><span id=\"" + drcc["name"] +  "_label\">");
		Response.Write (drcc["name"]);
		Response.Write (":</span><td align=left>");

		//20040413 WWR - If a custom database field is over the defined character length, use a TextArea control
		int fieldLength = int.Parse(drcc["length"].ToString());

		int permission_on_original = permission_level;

		if ((prev_project.Value != string.Empty)
		&& (project.SelectedItem == null || project.SelectedItem.Value != prev_project.Value))
		{
			permission_on_original = fetch_permission_level(prev_project.Value);
		}

		if (permission_on_original == Security.PERMISSION_READONLY
		|| permission_on_original == Security.PERMISSION_REPORTER)
		{
			Response.Write ("<span class=static>");
			if (drcc["datatype"].ToString() == "datetime")
			{
				Response.Write (btnet.Util.format_db_date(hash_custom_cols[(string)drcc["name"]]));
			}
			else
			{
				Response.Write (hash_custom_cols[(string)drcc["name"]]);
			}
			Response.Write ("</span>");
		}
		else
		{

			if ( fieldLength > minTextAreaSize )
			{
				Response.Write ("<textarea cols=\"" + minTextAreaSize + "\" rows=\"" + (((fieldLength/minTextAreaSize)>maxTextAreaRows) ? maxTextAreaRows : (fieldLength/minTextAreaSize)) + "\" " );
				Response.Write (" name=\"" + drcc["name"].ToString() + "\"");
				Response.Write (" id=\"" + drcc["name"].ToString() + "\" >");
				Response.Write (HttpUtility.HtmlEncode(Convert.ToString(hash_custom_cols[(string)drcc["name"]])));
				Response.Write ("</textarea>");
			}
			else
			{

				string dropdown_type = Convert.ToString(drcc["dropdown type"]);
				string dropdown_vals = Convert.ToString(drcc["vals"]);


				if (dropdown_type != "" || dropdown_vals != "")
				{
					string selected_value = Convert.ToString(hash_custom_cols[(string)drcc["name"]]);

					Response.Write ("<select ");

					Response.Write (" id=\"" + drcc["name"].ToString() + "\"");
					Response.Write (" name=\"" + drcc["name"].ToString() + "\"");
					Response.Write (">");

					if (dropdown_type != "users")
					{
						string[] options = btnet.Util.split_string_using_pipes(dropdown_vals);
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
					Response.Write ("<input type=text ");

					// match the size of the text field to the size of the database field
					if (drcc["datatype"].ToString().IndexOf("char") > -1)
					{
						if (drcc["datatype"].ToString() == "nvarchar")
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

					Response.Write (" name=\"" + drcc["name"].ToString() + "\"");
					Response.Write (" id=\"" + drcc["name"].ToString() + "\"");


					// output a date field according to the specified format
					if (hash_custom_cols[(string)drcc["name"]].GetType().ToString() == "System.DateTime")
					{
						Response.Write (
							" value=\""
							+ btnet.Util.format_db_date(hash_custom_cols[(string)drcc["name"]])
							+ "\"");

					}
					else
					{
						Response.Write (" value=\"");
						Response.Write (
							HttpUtility.HtmlEncode(
								Convert.ToString(
									hash_custom_cols[(string)drcc["name"]]
								)
							)
						);
						Response.Write ("\"");
					}

					Response.Write (">");
					if (drcc["datatype"].ToString() == "datetime")
					{
						Response.Write("<a style=\"font-size: 8pt;\"href=\"javascript:show_calendar('"
							+ btnet.Util.get_form_name()
							+ "."
							+ drcc["name"].ToString()
							+ "',null,null,'"
							+ btnet.Util.get_setting("JustDateFormat",btnet.Util.get_culture_info().DateTimeFormat.ShortDatePattern)
							+ "');\">[select]</a>");

					}
				}
			}
		}

		Response.Write ("</td></tr>");

	}


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


		for (int i = 1; i < 4; i++)
		{
			if ((int)project_dr["pj_enable_custom_dropdown" + Convert.ToString(i)] == 1)
			{
				Response.Write ("\n<tr><td nowrap>");
				Response.Write (project_dr["pj_custom_dropdown_label" + Convert.ToString(i)]);
				Response.Write ("<td nowrap>");


				int permission_on_original = permission_level;
				if ((prev_project.Value != string.Empty) && (project.SelectedItem.Value != prev_project.Value))
				{
					permission_on_original = fetch_permission_level(prev_project.Value);
				}
				if (permission_on_original == Security.PERMISSION_READONLY
				|| permission_on_original == Security.PERMISSION_REPORTER)
				{
					Response.Write ("<span class=static>");
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
					Response.Write (" name=pcd" + Convert.ToString(i) + ">");
					string[] options = btnet.Util.split_string_using_pipes(
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
	}



	%>

	</table>
	<table border=0 cellpadding=0 cellspacing=3 width=98%>

	<tr><td nowrap>
		<span id="plus_label" runat="server">
			<font size=0>
				<a href="#" onclick="<%= security.this_use_fckeditor ? "resize_iframe('fckeComment___Frame', 50);" : "resize_comment(10);" %>"><span id="toggle_link_plus">[+]</span></a>
				&nbsp;
				<a href="#" onclick="<%= security.this_use_fckeditor ? "resize_iframe('fckeComment___Frame', -50);" : "resize_comment(-10);" %>"><span id="toggle_link_minus">[-]</span></a>
			</font>
		</span>
		&nbsp;
		<span id="comment_label" runat="server">Comment:</span>
		<br>
		<textarea  id="comment" rows=4 cols=80 runat="server" class=txt></textarea>
		<FCKeditorV2:FCKeditor id="fckeComment" runat="server"></FCKeditorV2:FCKeditor>

	<tr><td  nowrap>
		<asp:checkbox runat="server" class=txt id="internal_only"/>
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
			value="Create or Edit"
			OnServerClick="on_update">

	</table>

	<input type=hidden id="new_id" runat="server" value="0">
	<input type=hidden id="prev_short_desc" runat="server">
	<input type=hidden id="prev_project" runat="server">
	<input type=hidden id="prev_org" runat="server">
	<input type=hidden id="prev_category" runat="server">
	<input type=hidden id="prev_priority" runat="server">
	<input type=hidden id="prev_assigned_to" runat="server">
	<input type=hidden id="prev_status" runat="server">
	<input type=hidden id="prev_udf" runat="server">
	<input type=hidden id="prev_pcd1" runat="server">
	<input type=hidden id="prev_pcd2" runat="server">
	<input type=hidden id="prev_pcd3" runat="server">
	<input type=hidden id="snapshot_timestamp" runat="server">

<%

	// create the "Prev" fields for the custom columns so that we
	// can create an audit trail of their changes.

	foreach (DataRow drcc in ds_custom_cols.Tables[0].Rows)
	{
		Response.Write ("<input type=hidden name=\"prev_");
		Response.Write (drcc["name"]);
		Response.Write ("\"");

		// output a date field according to the specified format
		if (hash_custom_cols[(string)drcc["name"]].GetType().ToString() == "System.DateTime")
		{

			Response.Write (
				" value=\""
				+ btnet.Util.format_db_date(hash_prev_custom_cols[(string)drcc["name"]]));
		}
		else
		{
			Response.Write (" value=\"");

			Response.Write (
				HttpUtility.HtmlEncode(
					Convert.ToString(
						hash_prev_custom_cols[(string)drcc["name"]]
					)
				)
			);

		}

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
			security.this_is_admin,
			security.this_can_edit_and_delete_posts,
			security.this_external_user);
	}

	%>


</div>

</div>
<% Response.Write(Application["custom_footer"]); %></body>
</html>