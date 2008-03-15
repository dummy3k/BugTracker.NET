<%@ Page language="C#" ValidateRequest="false" %>
<%@ Import Namespace="System.Collections.Generic" %>
<!--
Copyright 2002-2008 Corey Trager
Distributed under the terms of the GNU General Public License
-->
<!-- #include file = "inc.aspx" -->

<script language="C#" runat="server">

DbUtil dbutil;
Security security;
bool show_udf;
bool use_full_names = false;

DataTable dt_users = null;

string project_dropdown_select_cols = "";


///////////////////////////////////////////////////////////////////////
class ProjectDropdown
{
	public bool enabled = false;
	public string label = "";
	public string values = "";
};

class BtnetProject
{
	public Dictionary<int, ProjectDropdown> map_dropdowns = new Dictionary<int, ProjectDropdown>();
};

Dictionary<int, BtnetProject> map_projects = new Dictionary<int, BtnetProject>();

///////////////////////////////////////////////////////////////////////
void Page_Load(Object sender, EventArgs e)
{
	Util.do_not_cache(Response);
	dbutil = new DbUtil();
	security = new Security();
	security.check_security(dbutil, HttpContext.Current, Security.ANY_USER_OK);

	titl.InnerText = Util.get_setting("AppTitle","BugTracker.NET") + " - "
		+ "search";

	show_udf = (Util.get_setting("ShowUserDefinedBugAttribute","1") == "1");
	use_full_names = (Util.get_setting("UseFullNames","0") == "1");

	ds_custom_cols = Util.get_custom_columns(dbutil);

	dt_users = Util.get_related_users(security, dbutil);

	if (!IsPostBack)
	{
		load_drop_downs();
		project_custom_dropdown1_label.Style["display"] = "none";
		project_custom_dropdown1.Style["display"] = "none";

		project_custom_dropdown2_label.Style["display"] = "none";
		project_custom_dropdown2.Style["display"] = "none";

		project_custom_dropdown3_label.Style["display"] = "none";
		project_custom_dropdown3.Style["display"] = "none";

		// are there any project dropdowns?

		string sql = @"
select count(1)
from projects
where isnull(pj_enable_custom_dropdown1,0) = 1
or isnull(pj_enable_custom_dropdown2,0) = 1
or isnull(pj_enable_custom_dropdown3,0) = 1";

		int projects_with_custom_dropdowns = (int) dbutil.execute_scalar(sql);

		if (projects_with_custom_dropdowns == 0)
		{
			project.AutoPostBack = false;
		}

	}
	else
	{

		// get the project dropdowns

		string sql = @"
select
pj_id,
isnull(pj_enable_custom_dropdown1,0) pj_enable_custom_dropdown1,
isnull(pj_enable_custom_dropdown2,0) pj_enable_custom_dropdown2,
isnull(pj_enable_custom_dropdown3,0) pj_enable_custom_dropdown3,
isnull(pj_custom_dropdown_label1,'') pj_custom_dropdown_label1,
isnull(pj_custom_dropdown_label2,'') pj_custom_dropdown_label2,
isnull(pj_custom_dropdown_label3,'') pj_custom_dropdown_label3,
isnull(pj_custom_dropdown_values1,'') pj_custom_dropdown_values1,
isnull(pj_custom_dropdown_values2,'') pj_custom_dropdown_values2,
isnull(pj_custom_dropdown_values3,'') pj_custom_dropdown_values3
from projects
where isnull(pj_enable_custom_dropdown1,0) = 1
or isnull(pj_enable_custom_dropdown2,0) = 1
or isnull(pj_enable_custom_dropdown3,0) = 1";

		DataSet ds_projects = dbutil.get_dataset(sql);

		foreach (DataRow dr in ds_projects.Tables[0].Rows)
		{
			BtnetProject btnet_project = new BtnetProject();

			ProjectDropdown dropdown;

			dropdown = new ProjectDropdown();
			dropdown.enabled = Convert.ToBoolean((int)dr["pj_enable_custom_dropdown1"]);
			dropdown.label = (string)dr["pj_custom_dropdown_label1"];
			dropdown.values = (string)dr["pj_custom_dropdown_values1"];
			btnet_project.map_dropdowns[1] = dropdown;

			dropdown = new ProjectDropdown();
			dropdown.enabled = Convert.ToBoolean((int)dr["pj_enable_custom_dropdown2"]);
			dropdown.label = (string)dr["pj_custom_dropdown_label2"];
			dropdown.values = (string)dr["pj_custom_dropdown_values2"];
			btnet_project.map_dropdowns[2] = dropdown;

			dropdown = new ProjectDropdown();
			dropdown.enabled = Convert.ToBoolean((int)dr["pj_enable_custom_dropdown3"]);
			dropdown.label = (string)dr["pj_custom_dropdown_label3"];
			dropdown.values = (string)dr["pj_custom_dropdown_values3"];
			btnet_project.map_dropdowns[3] = dropdown;

			map_projects[(int) dr["pj_id"]] = btnet_project;

		}

		// which button did the user hit?

		if (project_changed.Value == "1" && project.AutoPostBack == true)
		{
			handle_project_custom_dropdowns();
		}
		else if (hit_submit_button.Value == "1")
		{
			handle_project_custom_dropdowns();
			do_query();
		}
		else
		{
			dv = (DataView) Session["bugs"];
			if (dv == null)
			{
				do_query();
			}
			sort_and_filter_dataview();
		}
	}

	hit_submit_button.Value = "0";
	project_changed.Value = "0";

	if (security.user.is_admin || security.user.can_edit_sql)
	{

	}
	else
	{
		visible_sql_label.Style["display"] = "none";
		visible_sql_text.Style["display"] = "none";
	}

}



///////////////////////////////////////////////////////////////////////
string build_where(string where, string clause)
{
	if (clause == "")
	{
		return where;
	}

	string sql = "";

	if (where == "")
	{
		sql = " where ";
		sql += clause;
	}
	else
	{
		sql = where;
		string and_or = and.Checked ? "and " : "or ";
		sql += and_or;
		sql += clause;
	}

	return sql;
}


///////////////////////////////////////////////////////////////////////
string build_clause_from_listbox(ListBox lb, string column_name)
{

	string clause = "";
	foreach (ListItem li in lb.Items)
	{
		if (li.Selected)
		{
			if (clause == "")
			{
				clause += column_name + " in (";
			}
			else
			{
				clause += ",";
			}
			clause += li.Value;
		}
	}

	if (clause != "")
	{
		clause += ") ";
	}

	return clause;

}


///////////////////////////////////////////////////////////////////////
string format_in_not_in(string s)
{
	if (s == "")
	{
		return "";
	}

	string vals = "(";
	string opts = "";

	string[] s2 = Util.split_string_using_commas(s);
	for (int i = 0; i < s2.Length; i++)
	{
		if (opts != "")
		{
			opts += ",";
		}

		opts += "N'";
		opts += s2[i].Replace("'","''");
		opts += "'";
	}
	vals += opts;
	vals += ")";
	return vals;
}


///////////////////////////////////////////////////////////////////////
List<ListItem> get_selected_projects()
{
    List<ListItem> selected_projects = new List<ListItem>();

	foreach (ListItem li in project.Items)
	{
        if (li.Selected)
			{
            selected_projects.Add(li);
		}
	}

    return selected_projects;
}


///////////////////////////////////////////////////////////////////////
void do_query()
{
	prev_sort.Value = "-1";
	prev_dir.Value = "ASC";
	new_page.Value = "0";

	// Create "WHERE" clause

	string where = "";

	string reported_by_clause = build_clause_from_listbox (reported_by, "bg_reported_user");
	string assigned_to_clause = build_clause_from_listbox (assigned_to, "bg_assigned_to_user");
	string project_clause = build_clause_from_listbox (project, "bg_project");

	string project_custom_dropdown1_clause
		= build_clause_from_listbox (project_custom_dropdown1, "bg_project_custom_dropdown_value1");
	string project_custom_dropdown2_clause
		= build_clause_from_listbox (project_custom_dropdown2, "bg_project_custom_dropdown_value2");
	string project_custom_dropdown3_clause
		= build_clause_from_listbox (project_custom_dropdown3, "bg_project_custom_dropdown_value3");

	string org_clause = build_clause_from_listbox (org, "bg_org");
	string category_clause = build_clause_from_listbox (category, "bg_category");
	string priority_clause = build_clause_from_listbox (priority, "bg_priority");
	string status_clause = build_clause_from_listbox (status, "bg_status");
	string udf_clause = "";

	if (show_udf)
	{
		udf_clause = build_clause_from_listbox(udf, "bg_user_defined_attribute");
	}


	// SQL "LIKE" uses [, %, and _ in a special way

	string like_string = like.Value.Replace("'", "''");
	like_string = like_string.Replace("[","[[]");
	like_string = like_string.Replace("%","[%]");
	like_string = like_string.Replace("_","[_]");

	string like2_string = like2.Value.Replace("'","''");
	like2_string = like2_string.Replace("[","[[]");
	like2_string = like2_string.Replace("%","[%]");
	like2_string = like2_string.Replace("_","[_]");

	string desc_clause = "";
	if (like.Value != "") {
		desc_clause = " bg_short_desc like";
		desc_clause += " N'%" + like_string + "%'\n";
	}

	string comments_clause = "";
	if (like2.Value != "") {
		comments_clause = " bg_id in (select bp_bug from bug_posts where bp_type in ('comment','received','sent') and isnull(bp_comment_search,bp_comment) like";
		comments_clause += " N'%" + like2_string + "%'";
		if (security.user.external_user) {
			comments_clause += " and bp_hidden_from_external_users = 0";
		}
		comments_clause += ")\n";
	}


	string comments_since_clause = "";
	if (comments_since.Value != "") {
		comments_since_clause = " bg_id in (select bp_bug from bug_posts where bp_type in ('comment','received','sent') and bp_date > '";
		comments_since_clause += Util.format_local_date_into_db_format(comments_since.Value).Replace(" 12:00:00","");
		comments_since_clause += "')\n";
	}

	string from_clause = "";
	if (from_date.Value != "")
	{
		from_clause = " bg_reported_date >= '" + Util.format_local_date_into_db_format(from_date.Value).Replace(" 12:00:00","") + "'\n";
	}

	string to_clause = "";
	if (to_date.Value != "")
	{
		to_clause = " bg_reported_date <= '" + Util.format_local_date_into_db_format(to_date.Value).Replace(" 00:00:00","") + " 23:59:59'\n";
	}

	string lu_from_clause = "";
	if (lu_from_date.Value != "")
	{
		lu_from_clause = " bg_last_updated_date >= '" + Util.format_local_date_into_db_format(lu_from_date.Value).Replace(" 12:00:00","") + "'\n";
	}

	string lu_to_clause = "";
	if (lu_to_date.Value != "")
	{
		lu_to_clause = " bg_last_updated_date <= '" + Util.format_local_date_into_db_format(lu_to_date.Value).Replace(" 00:00:00","") + " 23:59:59'\n";
	}


	where = build_where(where, reported_by_clause);
	where = build_where(where, assigned_to_clause);
	where = build_where(where, project_clause);
	where = build_where(where, project_custom_dropdown1_clause);
	where = build_where(where, project_custom_dropdown2_clause);
	where = build_where(where, project_custom_dropdown3_clause);
	where = build_where(where, org_clause);
	where = build_where(where, category_clause);
	where = build_where(where, priority_clause);
	where = build_where(where, status_clause);
	where = build_where(where, desc_clause);
	where = build_where(where, comments_clause);
	where = build_where(where, comments_since_clause);
	where = build_where(where, from_clause);
	where = build_where(where, to_clause);
	where = build_where(where, lu_from_clause);
	where = build_where(where, lu_to_clause);

	if (show_udf)
	{
		where = build_where(where, udf_clause);
	}

	foreach (DataRow drcc in ds_custom_cols.Tables[0].Rows)
	{
		string variable = (string)drcc["name"];
		string values = Request[variable];
		if (values == null)
		{
			values = "";
		}

		if (values != "")
		{

			string custom_clause;
			if (((string) drcc["datatype"] == "varchar" || (string) drcc["datatype"] == "nvarchar")
			&& (string) drcc["dropdown type"] == "")
			{
				custom_clause = " [" + variable + "] like '%" + values + "%'\n";
			}
			else
			{
				string in_not_in = format_in_not_in(values);
				custom_clause = " [" + variable + "] in " + in_not_in + "\n";
			}
			where = build_where(where, custom_clause);
		}
	}

	// The rest of the SQL is either built in or comes from Web.config

	string search_sql = Util.get_setting("SearchSQL","");

	if (search_sql == "")
	{

/*
select isnull(pr_background_color,'#ffffff') [color], bg_id [id],
bg_short_desc [desc],
bg_reported_date [reported on],
isnull(rpt.us_username,'') [reported by],
isnull(pj_name,'') [project],
isnull(og_name,'') [organization],
isnull(ct_name,'') [category],
isnull(pr_name,'') [priority],
isnull(asg.us_username,'') [assigned to],
isnull(st_name,'') [status],
isnull(udf_name,'') [MyUDF],
isnull([mycust],'') [mycust],
isnull([mycust2],'') [mycust2]
from bugs
left outer join users rpt on rpt.us_id = bg_reported_user
left outer join users asg on asg.us_id = bg_assigned_to_user
left outer join projects on pj_id = bg_project
left outer join orgs on og_id = bg_org
left outer join categories on ct_id = bg_category
left outer join priorities on pr_id = bg_priority
left outer join statuses on st_id = bg_status
left outer join user_defined_attribute on udf_id = bg_user_defined_attribute
order by bg_id desc
*/

		string select = "select isnull(pr_background_color,'#ffffff') [color], bg_id [id],\nbg_short_desc [desc]";

		select += "\n,bg_reported_date [reported on]";
		if (use_full_names)
		{
			select += "\n,isnull(rpt.us_lastname + ', ' + rpt.us_firstname,'') [reported by]";
		}
		else
		{
			select += "\n,isnull(rpt.us_username,'') [reported by]";
		}

		if (security.user.project_field_permission_level > 0)
		{
			select += ",\nisnull(pj_name,'') [project]";
		}

		if (security.user.org_field_permission_level > 0)
		{
			select += ",\nisnull(og_name,'') [organization]";
		}

		if (security.user.category_field_permission_level > 0)
		{
			select += ",\nisnull(ct_name,'') [category]";
		}

		if (security.user.priority_field_permission_level > 0)
		{
			select += ",\nisnull(pr_name,'') [priority]";
		}

		if (security.user.assigned_to_field_permission_level > 0)
		{
			if (use_full_names)
			{
				select += ",\nisnull(asg.us_lastname + ', ' + asg.us_firstname,'') [assigned to]";
			}
			else
			{
				select += ",\nisnull(asg.us_username,'') [assigned to]";
			}
		}

		if (security.user.status_field_permission_level > 0)
		{
			select += ",\nisnull(st_name,'') [status]";
		}

		if (security.user.udf_field_permission_level > 0)
		{
			if (show_udf)
			{
				string udf_name = Util.get_setting("UserDefinedBugAttributeName","YOUR ATTRIBUTE");
				select += ",\nisnull(udf_name,'') [" + udf_name + "]";
			}
		}

		// let results include custom columns
		string custom_cols_sql = "";
		int user_type_cnt = 1;
		foreach (DataRow drcc in ds_custom_cols.Tables[0].Rows)
		{
			if (Convert.ToString(drcc["dropdown type"]) == "users")
			{
				custom_cols_sql += ",\nisnull(users"
					+ Convert.ToString(user_type_cnt++)
					+ ".us_username,'') "
					+ "["
					+ drcc["name"].ToString() + "]";
			}
			else
			{
				if (Convert.ToString(drcc["datatype"]) == "decimal")
				{
					custom_cols_sql += ",\nisnull(["
						+ drcc["name"].ToString()
						+ "],0)["
						+ drcc["name"].ToString() + "]";
				}
				else
				{
					custom_cols_sql += ",\nisnull(["
						+ drcc["name"].ToString()
						+ "],'')["
						+ drcc["name"].ToString() + "]";
				}
			}
		}

		select += custom_cols_sql;

		// Handle project custom dropdowns
		List<ListItem> selected_projects = get_selected_projects();

		string project_dropdown_select_cols_server_side = "";

        string alias1 = null;
        string alias2 = null;
        string alias3 = null;

        foreach (ListItem selected_project in selected_projects)
		{
            if (selected_project.Value == "0")
                continue;

			int pj_id = Convert.ToInt32(selected_project.Value);

			if (map_projects.ContainsKey(pj_id))
			{

				BtnetProject btnet_project = map_projects[pj_id];

				if (btnet_project.map_dropdowns[1].enabled)
				{
					if (alias1 == null)
					{
						alias1 = btnet_project.map_dropdowns[1].label;
					}
					else
					{
						alias1 = "dropdown1";
					}
				}

				if (btnet_project.map_dropdowns[2].enabled)
				{
					if (alias2 == null)
					{
						alias2 = btnet_project.map_dropdowns[2].label;
					}
					else
					{
						alias2 = "dropdown2";
					}
				}

				if (btnet_project.map_dropdowns[3].enabled)
				{
					if (alias3 == null)
					{
						alias3 = btnet_project.map_dropdowns[3].label;
					}
					else
					{
						alias3 = "dropdown3";
					}
				}


			}
		}

        if (alias1 != null)
        {
            project_dropdown_select_cols_server_side
                += ",\nisnull(bg_project_custom_dropdown_value1,'') [" + alias1 +"]";
        }
        if (alias2 != null)
        {
            project_dropdown_select_cols_server_side
                += ",\nisnull(bg_project_custom_dropdown_value2,'') [" + alias2 + "]";
        }
        if (alias3 != null)
        {
            project_dropdown_select_cols_server_side
                += ",\nisnull(bg_project_custom_dropdown_value3,'') [" + alias3 + "]";
        }

		select += project_dropdown_select_cols_server_side;

		select += @" from bugs
			left outer join users rpt on rpt.us_id = bg_reported_user
			left outer join users asg on asg.us_id = bg_assigned_to_user
			left outer join projects on pj_id = bg_project
			left outer join orgs on og_id = bg_org
			left outer join categories on ct_id = bg_category
			left outer join priorities on pr_id = bg_priority
			left outer join statuses on st_id = bg_status
			";

		user_type_cnt = 1;
		foreach (DataRow drcc in ds_custom_cols.Tables[0].Rows)
		{
			if (Convert.ToString(drcc["dropdown type"]) == "users")
			{
				select += "left outer join users users"
					+ Convert.ToString(user_type_cnt)
					+ " on users"
					+ Convert.ToString(user_type_cnt)
					+ ".us_id = bugs."
					+ "[" + drcc["name"].ToString() + "]\n";

				user_type_cnt++;

			}
		}


		if (show_udf)
		{
			select += "left outer join user_defined_attribute on udf_id = bg_user_defined_attribute";
		}

		sql = select + where + " order by bg_id desc";

	}
	else
	{
		search_sql = search_sql.Replace("[br]","\n");
		sql = search_sql.Replace("$WHERE$", where);
	}

	sql = Util.alter_sql_per_project_permissions(sql, security);

	DataSet ds = dbutil.get_dataset(sql);
	dv = new DataView (ds.Tables[0]);
	Session["bugs"] = dv;
	Session["bugs_unfiltered"] = ds.Tables[0];
}

///////////////////////////////////////////////////////////////////////
void load_project_custom_dropdown(ListBox dropdown, string vals_string, Dictionary<String, String> duplicate_detection_dictionary)
{
	string[] vals_array = btnet.Util.split_string_using_pipes(vals_string);
	for (int i = 0; i < vals_array.Length; i++)
	{
	    if (!duplicate_detection_dictionary.ContainsKey(vals_array[i]))
	    {
		dropdown.Items.Add(new ListItem(vals_array[i], "'" + vals_array[i].Replace("'","''") + "'"));
		    duplicate_detection_dictionary.Add(vals_array[i], vals_array[i]);
		}
	}
}

void handle_project_custom_dropdowns()
{

	// How many projects selected?
	List<ListItem> selected_projects = get_selected_projects();
	Dictionary<String, String>[] dupe_detection_dictionaries = new Dictionary<String, String>[3];
    Dictionary<String, String>[] previous_selection_dictionaries = new Dictionary<String, String>[3];
	for (int i = 0; i < dupe_detection_dictionaries.Length; i++)
	{
        // Initialize Dictionary to accumulate ListItem values as they are added to the ListBox
        // so that duplicate values from multiple projects are not added to the ListBox twice.
	    dupe_detection_dictionaries[i] = new Dictionary<String, String>();

        previous_selection_dictionaries[i] = new Dictionary<String, String>();
	}

    // Preserve user's previous selections (necessary if this is called during a postback).
    foreach (ListItem li in project_custom_dropdown1.Items)
    {
        if (li.Selected)
        {
            previous_selection_dictionaries[0].Add(li.Value, li.Value);
        }
    }
    foreach (ListItem li in project_custom_dropdown2.Items)
    {
        if (li.Selected)
        {
            previous_selection_dictionaries[1].Add(li.Value, li.Value);
        }
    }
    foreach (ListItem li in project_custom_dropdown3.Items)
    {
        if (li.Selected)
        {
            previous_selection_dictionaries[2].Add(li.Value, li.Value);
        }
    }

	project_dropdown_select_cols = "";

    project_custom_dropdown1_label.InnerText = "";
    project_custom_dropdown2_label.InnerText = "";
    project_custom_dropdown3_label.InnerText = "";

    project_custom_dropdown1.Items.Clear();
    project_custom_dropdown2.Items.Clear();
    project_custom_dropdown3.Items.Clear();

	foreach (ListItem selected_project in selected_projects)
	{
		// Read the project dropdown info from the db.
		// Load the dropdowns as necessary

        if (selected_project.Value == "0")
            continue;

		int pj_id = Convert.ToInt32(selected_project.Value);

		if (map_projects.ContainsKey(pj_id))
		{

			BtnetProject btnet_project = map_projects[pj_id];

			if (btnet_project.map_dropdowns[1].enabled)
			{
				if (project_custom_dropdown1_label.InnerText == "")
				{
					project_custom_dropdown1_label.InnerText = btnet_project.map_dropdowns[1].label;
					project_custom_dropdown1_label.Style["display"] = "inline";
					project_custom_dropdown1.Style["display"] = "block";
				}
				else if (project_custom_dropdown1_label.InnerText != btnet_project.map_dropdowns[1].label)
				{
					project_custom_dropdown1_label.InnerText = "dropdown1";
				}
				load_project_custom_dropdown(project_custom_dropdown1, btnet_project.map_dropdowns[1].values, dupe_detection_dictionaries[0]);
			}

			if (btnet_project.map_dropdowns[2].enabled)
			{
				if (project_custom_dropdown2_label.InnerText == "")
				{
					project_custom_dropdown2_label.InnerText = btnet_project.map_dropdowns[2].label;
					project_custom_dropdown2_label.Style["display"] = "inline";
					project_custom_dropdown2.Style["display"] = "block";
				}
				else if (project_custom_dropdown2_label.InnerText != btnet_project.map_dropdowns[2].label)
				{
					project_custom_dropdown2_label.InnerText = "dropdown2";
				}
				load_project_custom_dropdown(project_custom_dropdown2, btnet_project.map_dropdowns[2].values, dupe_detection_dictionaries[1]);
			}

			if (btnet_project.map_dropdowns[3].enabled)
			{
				if (project_custom_dropdown3_label.InnerText == "")
				{
					project_custom_dropdown3_label.InnerText = btnet_project.map_dropdowns[3].label;
					project_custom_dropdown3_label.Style["display"] = "inline";
					project_custom_dropdown3.Style["display"] = "block";
					load_project_custom_dropdown(project_custom_dropdown3, btnet_project.map_dropdowns[3].values, dupe_detection_dictionaries[2]);
				}
				else if (project_custom_dropdown3_label.InnerText != btnet_project.map_dropdowns[3].label)
				{
					project_custom_dropdown3_label.InnerText = "dropdown3";
				}
				load_project_custom_dropdown(project_custom_dropdown3, btnet_project.map_dropdowns[3].values, dupe_detection_dictionaries[2]);
			}
		}
	}

    if (project_custom_dropdown1_label.InnerText == "")
	{
		project_custom_dropdown1.Items.Clear();
		project_custom_dropdown1_label.Style["display"] = "none";
		project_custom_dropdown1.Style["display"] = "none";
    }
    else
    {
        project_custom_dropdown1_label.Style["display"] = "inline";
        project_custom_dropdown1.Style["display"] = "block";
        project_dropdown_select_cols
            += ",\\nisnull(bg_project_custom_dropdown_value1,'') [" + project_custom_dropdown1_label.InnerText + "]";
    }

    if (project_custom_dropdown2_label.InnerText == "")
    {
		project_custom_dropdown2.Items.Clear();
		project_custom_dropdown2_label.Style["display"] = "none";
		project_custom_dropdown2.Style["display"] = "none";
    }
    else
    {
        project_custom_dropdown2_label.Style["display"] = "inline";
        project_custom_dropdown2.Style["display"] = "block";
        project_dropdown_select_cols
            += ",\\nisnull(bg_project_custom_dropdown_value2,'') [" + project_custom_dropdown2_label.InnerText + "]";
    }

    if (project_custom_dropdown3_label.InnerText == "")
    {
		project_custom_dropdown3.Items.Clear();
		project_custom_dropdown3_label.Style["display"] = "none";
		project_custom_dropdown3.Style["display"] = "none";
	}
    else
    {
        project_custom_dropdown3_label.Style["display"] = "inline";
        project_custom_dropdown3.Style["display"] = "block";
        project_dropdown_select_cols
            += ",\\nisnull(bg_project_custom_dropdown_value3,'') [" + project_custom_dropdown3_label.InnerText + "]";
    }

    // Restore user's previous selections.
    foreach (ListItem li in project_custom_dropdown1.Items)
    {
        li.Selected = (previous_selection_dictionaries[0].ContainsKey(li.Value));
    }
    foreach (ListItem li in project_custom_dropdown2.Items)
    {
        li.Selected = (previous_selection_dictionaries[1].ContainsKey(li.Value));
    }
    foreach (ListItem li in project_custom_dropdown3.Items)
    {
        li.Selected = (previous_selection_dictionaries[2].ContainsKey(li.Value));
    }
}

///////////////////////////////////////////////////////////////////////
void load_drop_downs()
{

	reported_by.DataSource = dt_users;
	reported_by.DataTextField = "us_username";
	reported_by.DataValueField = "us_id";
	reported_by.DataBind();


	// only show projects where user has permissions
	if (security.user.is_admin)
	{
		sql = "/* drop downs */ select pj_id, pj_name from projects order by pj_name;";
	}
	else
	{
		sql = @"/* drop downs */ select pj_id, pj_name
			from projects
			left outer join project_user_xref on pj_id = pu_project
			and pu_user = $us
			where isnull(pu_permission_level,$dpl) <> 0
			order by pj_name;";

		sql = sql.Replace("$us",Convert.ToString(security.user.usid));
		sql = sql.Replace("$dpl", Util.get_setting("DefaultPermissionLevel","2"));
	}


	if (security.user.other_orgs_permission_level != 0)
	{
		sql += " select og_id, og_name from orgs order by og_name;";
	}
	else
	{
		sql += " select og_id, og_name from orgs where og_id = " + Convert.ToInt32(security.user.org) + " order by og_name;";
		org.Visible = false;
		org_label.Visible = false;
	}

	sql += @"
	select ct_id, ct_name from categories order by ct_sort_seq, ct_name;
	select pr_id, pr_name from priorities order by pr_sort_seq, pr_name;
	select st_id, st_name from statuses order by st_sort_seq, st_name;
	select udf_id, udf_name from user_defined_attribute order by udf_sort_seq, udf_name";

	DataSet ds_dropdowns = dbutil.get_dataset(sql);

	project.DataSource = ds_dropdowns.Tables[0];
	project.DataTextField = "pj_name";
	project.DataValueField = "pj_id";
	project.DataBind();
	project.Items.Insert(0, new ListItem("[no project]", "0"));

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

	priority.DataSource = ds_dropdowns.Tables[3];
	priority.DataTextField = "pr_name";
	priority.DataValueField = "pr_id";
	priority.DataBind();
	priority.Items.Insert(0, new ListItem("[no priority]", "0"));

	status.DataSource = ds_dropdowns.Tables[4];
	status.DataTextField = "st_name";
	status.DataValueField = "st_id";
	status.DataBind();
	status.Items.Insert(0, new ListItem("[no status]", "0"));

	assigned_to.DataSource = reported_by.DataSource;
	assigned_to.DataTextField = "us_username";
	assigned_to.DataValueField = "us_id";
	assigned_to.DataBind();
	assigned_to.Items.Insert(0, new ListItem("[not assigned]", "0"));

	if (show_udf)
	{
		udf.DataSource = ds_dropdowns.Tables[5];
		udf.DataTextField = "udf_name";
		udf.DataValueField = "udf_id";
		udf.DataBind();
		udf.Items.Insert(0, new ListItem("[none]", "0"));
	}

	if (security.user.project_field_permission_level == 0)
	{
		project_label.Style["display"] = "none";
		project.Style["display"] = "none";
	}
	if (security.user.org_field_permission_level == 0)
	{
		org_label.Style["display"] = "none";
		org.Style["display"] = "none";
	}
	if (security.user.category_field_permission_level == 0)
	{
		category_label.Style["display"] = "none";
		category.Style["display"] = "none";
	}
	if (security.user.priority_field_permission_level == 0)
	{
		priority_label.Style["display"] = "none";
		priority.Style["display"] = "none";
	}
	if (security.user.status_field_permission_level == 0)
	{
		status_label.Style["display"] = "none";
		status.Style["display"] = "none";
	}
	if (security.user.assigned_to_field_permission_level == 0)
	{
		assigned_to_label.Style["display"] = "none";
		assigned_to.Style["display"] = "none";
	}
	if (security.user.udf_field_permission_level == 0)
	{
		udf_label.Style["display"] = "none";
		udf.Style["display"] = "none";
	}

}




</script>
<!-- #include file = "inc_bugs.inc" -->

<html>
<head>
<title id="titl" runat="server">btnet search</title>
<link rel="StyleSheet" href="btnet.css" type="text/css">
<!-- use btnet_edit_bug.css to control positioning on edit_bug.asp.  use btnet_search.css to control position on search.aspx  -->
<link rel="StyleSheet" href="custom/btnet_search.css" type="text/css">

<script type="text/javascript" language="JavaScript" src="overlib_mini.js"></script>
<script type="text/javascript" language="JavaScript" src="calendar.js"></script>
<script type="text/javascript" language="JavaScript" src="bug_list.js"></script>
<script type="text/javascript" language="JavaScript" src="suggest.js"></script>

<script>

saerch_suggest_min_chars = <% Response.Write(Util.get_setting("SearchSuggestMinChars","3")); %>


// start of mass edit javascript
<% if (security.user.is_admin || security.user.can_mass_edit_bugs) { %>

function select_all(sel)
{
	var frm = document.getElementById("massform");
	for (var i = 0; i < frm.elements.length; i++)
	{
		var varname = frm.elements[i].name;
		if (!isNaN(parseInt(varname)))
		{
			frm.elements[i].checked = sel;
		}
	}
}

function validate_mass()
{

	var at_least_one_selected = false;

	// make sure at least one item is selected
	var frm = document.getElementById("massform");
	for (var i = 0; i < frm.elements.length; i++)
	{
		var varname = frm.elements[i].name;
		if (!isNaN(parseInt(varname)))
		{
			var checkbox = frm.elements[i];
			if (checkbox.checked == true)
			{
				at_least_one_selected = true;
				break;
			}
		}
	}

	if (!at_least_one_selected)
	{
		alert ("No items selected for mass update/delete.");
		return false;
	}

	if (frm.mass_project.selectedIndex==0
	&& frm.mass_org.selectedIndex==0
	&& frm.mass_category.selectedIndex==0
	&& frm.mass_priority.selectedIndex==0
	&& frm.mass_assigned_to.selectedIndex==0
	&& frm.mass_status.selectedIndex==0)
	{
		if (!frm.mass_delete.checked)
		{
			alert ("No updates were specified and delete wasn't checked.  Please specify updates or delete.");
			return false;
		}
	}
	else
	{
		if (frm.mass_delete.checked)
		{
			alert ("Both updates and delete were specified.   Please select one or the other.");
			return false;
		}
	}

	return true;
}

function load_one_massedit_select(from_id, to_id)
{
	var from;
	var to;
	var option;

	from = document.getElementById(from_id);
	to = document.getElementById(to_id);

	option = document.createElement('option');
	option.value = -1;
	option.text = "[do not update]";
	try {
		to.add(option, null); // standards compliant; doesn't work in IE
	}
	catch(ex) {
		to.add(option); // IE only
	}

	for (var i = 0; i < from.options.length; i++)
	{
		option = document.createElement('option');
		option.value = from.options[i].value;
		option.text = from.options[i].text;
		try {
			to.add(option, null); // standards compliant; doesn't work in IE
		}
		catch(ex) {
			to.add(option); // IE only
		}
	}

}

function load_massedit_selects()
{

	load_one_massedit_select ("project","mass_project");
	load_one_massedit_select ("org","mass_org");
	load_one_massedit_select ("category","mass_category");
	load_one_massedit_select ("priority","mass_priority");
	load_one_massedit_select ("assigned_to","mass_assigned_to");
	load_one_massedit_select ("status","mass_status");
}

<% } %> // end of mass edit javascript

function build_where(where, clause)
{
	if (clause == "") return where;

	var sql = "";

	if (where == "")
	{
		sql = "where ";
		sql += clause;
	}
	else
	{
		sql = where;
		and_or = document.getElementById("and").checked ? "and " : "or ";
		sql += and_or;
		sql += clause;
	}

	return sql;
}


function build_clause_from_options(options, column_name)
{

	var clause = ""
	for (i=0; i < options.length; i++)
	{
		if (options[i].selected)
		{
			if (clause == "")
			{
				clause = " " + column_name + " in (";
			}
			else
			{
				clause += ",";
			}

			clause += options[i].value;
		}
	}
	if (clause != "") clause += ")\n";

	return clause;
}


function in_not_in_vals(el)
{

	var vals = "";

	if (el.tagName == "INPUT")
	{
		if (el.value == "")
		{
			return vals;
		}
		vals = "("

		var opts = ""
		val_array = el.value.split(",")
		for (i = 0; i < val_array.length; i++)
		{
			if (opts != "")
			{
				opts += ","
			}

			opts += "N'"
			opts += val_array[i].replace(/'/ig,"''")
			opts += "'"  // "
		}
		vals += opts
		vals += ")\n"

	}
	else if (el.tagName == "SELECT")
	{
		if (el.selectedIndex == -1)
		{
			return vals;
		}
		vals = "("

		var opts = ""
		for (i = 0; i < el.options.length; i++)
		{
			if (el.options[i].selected)
			{
				if (opts != "")
				{
					opts += ","
				}

				opts += "N'"
				opts += el.options[i].value.replace(/'/ig,"''")
				opts += "'" // "
			}
		}
		if (opts == "N''")
		{
			return ""
		}
		vals += opts
		vals += ")\n"
	}

	//alert(vals)
	return vals;
}


function on_change()
{
	var frm = document.forms[1];


	// Build "WHERE" clause

	var where = "";

	var reported_by_clause = build_clause_from_options (frm.reported_by.options, "bg_reported_user");
	var assigned_to_clause = build_clause_from_options (frm.assigned_to.options, "bg_assigned_to_user");
	var project_clause = build_clause_from_options (frm.project.options, "bg_project");

	var project_custom_dropdown1_clause = build_clause_from_options (
		frm.project_custom_dropdown1.options, "bg_project_custom_dropdown_value1");
	var project_custom_dropdown2_clause = build_clause_from_options (
		frm.project_custom_dropdown2.options, "bg_project_custom_dropdown_value2");
	var project_custom_dropdown3_clause = build_clause_from_options (
		frm.project_custom_dropdown3.options, "bg_project_custom_dropdown_value3");

<%
	if (security.user.other_orgs_permission_level != 0)
	{
%>
		var org_clause = build_clause_from_options (frm.org.options, "bg_org");
<%
	}
	else
	{
%>
	var org_clause = "";
<%
	}
%>
	var category_clause = build_clause_from_options (frm.category.options, "bg_category");
	var priority_clause = build_clause_from_options (frm.priority.options, "bg_priority");
	var status_clause = build_clause_from_options (frm.status.options, "bg_status");
	var udf_clause = "";

<%
	if (show_udf)

	{
%>
		udf_clause = build_clause_from_options(frm.udf.options, "bg_user_defined_attribute");
<%
	}
%>



	// SQL "LIKE" uses [, %, and _ in a special way

	like_string = frm.like.value.replace(/'/gi,"''");
	like_string = like_string.replace(/\[/gi,"[[]");
	like_string = like_string.replace(/%/gi,"[%]");
	like_string = like_string.replace(/_/gi,"[_]");

	like2_string = frm.like2.value.replace(/'/gi,"''");
	like2_string = like2_string.replace(/\[/gi,"[[]");
	like2_string = like2_string.replace(/%/gi,"[%]");
	like2_string = like2_string.replace(/_/gi,"[_]");

	// "    this line is only here to help unconfuse the syntax coloring in my editor

	var desc_clause = ""
	if (frm.like.value != "") {
		desc_clause = " bg_short_desc like";
		desc_clause += " N'%" + like_string + "%'\n";
	}

	var comments_clause = ""
	if (frm.like2.value != "") {
		comments_clause = " bg_id in (select bp_bug from bug_posts where bp_type in ('comment','received','sent') and isnull(bp_comment_search,bp_comment) like";
		comments_clause += " N'%" + like2_string + "%'";
		<% if (security.user.external_user) { %>
		comments_clause += " and bp_hidden_from_external_users = 0"
		<% } %>
		comments_clause += ")\n";
	}

	var comments_since_clause = ""
	if (frm.comments_since.value != "") {
		comments_since_clause = " bg_id in (select bp_bug from bug_posts where bp_type in ('comment','received','sent') and bp_date > '";
		comments_since_clause += frm.comments_since.value + "')\n";
	}

	var from_clause = "";
	if (frm.from_date.value != "")
	{
		from_clause = " bg_reported_date >= '" + frm.from_date.value + "'\n";
	}

	var to_clause = "";
	if (frm.to_date.value != "")
	{
		to_clause = " bg_reported_date <= '" + frm.to_date.value + " 23:59:59'\n";
	}

	var lu_from_clause = "";
	if (frm.lu_from_date.value != "")
	{
		lu_from_clause = " bg_last_updated_date >= '" + frm.lu_from_date.value + "'\n";
	}

	var lu_to_clause = "";
	if (frm.lu_to_date.value != "")
	{
		lu_to_clause = " bg_last_updated_date <= '" + frm.lu_to_date.value + " 23:59:59'\n";
	}

<%
	// echo the custom input columns as the user types them
	int custom_count = 1;
	foreach (DataRow drcc in ds_custom_cols.Tables[0].Rows)
	{
		string clause = "custom_clause_" + Convert.ToString(custom_count++);
		string custom_col = drcc["name"].ToString();

		if (((string) drcc["datatype"] == "varchar" || (string) drcc["datatype"] == "nvarchar")
		&& (string) drcc["dropdown type"] == "")
		{
			// my_text_filed like '%val%'
			Response.Write ("var " + clause + " = \"\";\n");
			Response.Write ("el = document.getElementById('" +  custom_col + "')\n");
			Response.Write ("if (el.value != \"\")\n");
			Response.Write ("{\n\t");
			Response.Write (clause + " = \" [" + custom_col + "] like '%\" + el.value + \"%'\\n\"\n");
			Response.Write ("\twhere = build_where(where, " + clause + ");\n");
			Response.Write ("}\n\n");
		}
		else
		{
			// my_field in (val1, val2, val3)
			Response.Write ("var " + clause + " = \"\";\n");
			Response.Write ("el = document.getElementById('" +  custom_col + "')\n");
			Response.Write ("vals = in_not_in_vals(el)\n");
			Response.Write ("if (vals != \"\")\n");
			Response.Write ("{\n\t");
			Response.Write (clause + " = \" [" + custom_col + "] in \" + vals\n");
			Response.Write ("\twhere = build_where(where, " + clause + ");\n");
			Response.Write ("}\n\n");
		}
	}
%>

	where = build_where(where, reported_by_clause);
	where = build_where(where, assigned_to_clause);
	where = build_where(where, project_clause);
	where = build_where(where, project_custom_dropdown1_clause);
	where = build_where(where, project_custom_dropdown2_clause);
	where = build_where(where, project_custom_dropdown3_clause);
	where = build_where(where, org_clause);
	where = build_where(where, category_clause);
	where = build_where(where, priority_clause);
	where = build_where(where, status_clause);
	where = build_where(where, desc_clause);
	where = build_where(where, comments_clause);
	where = build_where(where, comments_since_clause);
	where = build_where(where, from_clause);
	where = build_where(where, to_clause);
	where = build_where(where, lu_from_clause);
	where = build_where(where, lu_to_clause);
	where = build_where(where, udf_clause);

<%
	string search_sql = Util.get_setting("SearchSQL","");

	if (search_sql == "")
	{

%>
		var select = "select isnull(pr_background_color,'#ffffff') [color], bg_id [id]";
		select += ",\nbg_short_desc [desc]"
		select += ",\nbg_reported_date [reported on]"

<%
		if (use_full_names)
		{
%>
			select += ",\nisnull(rpt.us_lastname + ', ' + rpt.us_firstname,'') [reported by]";
<%
		}
		else
		{
%>
			select += ",\nisnull(rpt.us_username,'') [reported by]";
<%
		}

		if (security.user.project_field_permission_level > 0)
		{
%>
			select += ",\nisnull(pj_name,'') [project]"
<%
		}

		if (security.user.org_field_permission_level > 0)
		{
%>
			select += ",\nisnull(og_name,'') [organization]"
<%
		}

		if (security.user.category_field_permission_level > 0)
		{
%>
			select += ",\nisnull(ct_name,'') [category]";
<%
		}

		if (security.user.priority_field_permission_level > 0)
		{
%>
			select += ",\nisnull(pr_name,'') [priority]"
<%
		}

		if (security.user.assigned_to_field_permission_level > 0)
		{
			if (use_full_names)
			{
%>
				select += ",\nisnull(asg.us_lastname + ', ' + asg.us_firstname,'') [assigned to]";
<%
			}
			else
			{
%>
				select += ",\nisnull(asg.us_username,'') [assigned to]";
<%
			}
		}

		if (security.user.status_field_permission_level > 0)
		{
%>
			select += ",\nisnull(st_name,'') [status]";
<%
		}

		if (security.user.udf_field_permission_level > 0)
		{
			if (show_udf)
			{
				string udf_name = Util.get_setting("UserDefinedBugAttributeName","YOUR ATTRIBUTE");
				Response.Write ("select += \",\\nisnull(udf_name,'') [" + udf_name + "]\"");
			}
		}


		// add the custom fields to the columns
		int user_dropdown_cnt = 1;
		foreach (DataRow drcc in ds_custom_cols.Tables[0].Rows)
		{
			if (Convert.ToString(drcc["dropdown type"]) == "users")
			{
				Response.Write ("\nselect += \", \\nisnull(users"
				+ Convert.ToString(user_dropdown_cnt)
				+ ".us_username,'') ["
				+ Convert.ToString(drcc["name"])
				+ "]\"");
				user_dropdown_cnt++;
			}
			else
			{
				if (Convert.ToString(drcc["datatype"]) == "decimal")
				{
					Response.Write ("\nselect += \", \\nisnull(["
					+ Convert.ToString(drcc["name"])
					+ "],0) ["
					+ Convert.ToString(drcc["name"])
					+ "]\"");
				}
				else
				{
					Response.Write ("\nselect += \", \\nisnull(["
					+ Convert.ToString(drcc["name"])
					+ "],'') ["
					+ Convert.ToString(drcc["name"])
					+ "]\"");
				}
			}
		}

		Response.Write ("\nselect += \"" + project_dropdown_select_cols + "\"");
%>

		select += "\nfrom bugs\n";
		select += "left outer join users rpt on rpt.us_id = bg_reported_user\n";
		select += "left outer join users asg on asg.us_id = bg_assigned_to_user\n";
		select += "left outer join projects on pj_id = bg_project\n";
		select += "left outer join orgs on og_id = bg_org\n";
		select += "left outer join categories on ct_id = bg_category\n";
		select += "left outer join priorities on pr_id = bg_priority\n";
		select += "left outer join statuses on st_id = bg_status\n";

<%
	// do the joins related to "user" dropdowns
		user_dropdown_cnt = 1;
		foreach (DataRow drcc in ds_custom_cols.Tables[0].Rows)
		{
			if (Convert.ToString(drcc["dropdown type"]) == "users")
			{
				Response.Write ("select += \"left outer join users users");
				Response.Write (Convert.ToString(user_dropdown_cnt));
				Response.Write (" on users");
				Response.Write (Convert.ToString(user_dropdown_cnt));
				Response.Write (".us_id = bugs.");
				Response.Write ("[");
				Response.Write (drcc["name"]);
				Response.Write ("]\\n\"\n");
				user_dropdown_cnt++;
			}
		}

		if (show_udf)
		{
%>
			select += "left outer join user_defined_attribute on udf_id = bg_user_defined_attribute\n";
<%
		}
%>

		frm.query.value = select + where + 'order by bg_id desc';
<%
	} // else use sql from web config
	else
	{
%>
		var search_sql = "<% Response.Write(search_sql.Replace("\r\n","")); %>";
		search_sql = search_sql.replace(/\[br\]/g,"\n");
		frm.query.value =  search_sql.replace(/\$WHERE\$/, where);
<%
	}
%>

	// I don't understand why this doesn't work in IE.   Did it used to work?
	document.getElementById("visible_sql_text").firstChild.nodeValue = frm.query.value;
	//document.getElementById("visible_sql_text").innerHTML = frm.query.value;
}

function set_hit_submit_button() {
	document.forms[1].hit_submit_button.value = "1";
}


var shown = true;
function showhide_form()
{
	var frm =  document.getElementById("<% Response.Write(Util.get_form_name()); %>");
	if (shown)
	{
		frm.style.display = "none";
		shown = false;
		showhide.firstChild.nodeValue = "show form";
	}
	else
	{
		frm.style.display = "block";
		shown = true;
		showhide.firstChild.nodeValue = "hide form";
	}
}

function set_project_changed() {
	on_change();
	document.forms[1].project_changed.value = "1";
}

</script>




</head>
<body onload="on_change()">
<% security.write_menu(Response, "search"); %>

<div id="overDiv" style="position:absolute; visibility:hidden; z-index:1000;"></div>
<div id="suggest_popup" style="position:absolute; display:none; z-index:1000;"></div>
<div id="popup" class="buglist_popup"></div>

<div class=align>

<% if (!security.user.adds_not_allowed) { %>
<a href=edit_bug.aspx>add new <% Response.Write(Util.get_setting("SingularBugLabel","bug")); %></a>
<% } %>

<a style='margin-left: 40px;' href='javascript:showhide_form()' id='showhide'>hide form</a>



<table border=0><tr><td>

<tr><td>
<div id=searchfrom>
<form class=frm method="post" runat="server" onmouseover="hide_suggest()">

<table border=0 cellpadding=6 cellspacing=0>
	<tr>
		<td colspan="10"><span class=smallnote>Hold down Ctrl key to select multiple items.</span></td>
	</tr>

	<tr>
		<td nowrap><span class=lbl>reported by:</span><br>
		<asp:ListBox Rows=6 SelectionMode="Multiple" id="reported_by" runat="server" onchange="on_change()">
		</asp:ListBox>
		</td>

		<td nowrap><span class=lbl id="category_label" runat="server">category:</span><br>
		<asp:ListBox Rows=6 SelectionMode="Multiple" id="category" runat="server" onchange="on_change()">
		</asp:ListBox>
		</td>

		<td nowrap><span class=lbl id="priority_label" runat="server">priority:</span><br>
		<asp:ListBox Rows=6 SelectionMode="Multiple" id="priority" runat="server" onchange="on_change()">
		</asp:ListBox>
		</td>

		<td nowrap><span class=lbl id="assigned_to_label" runat="server">assigned to:</span><br>
		<asp:ListBox Rows=6 SelectionMode="Multiple" id="assigned_to" runat="server" onchange="on_change()">
		</asp:ListBox>
		</td>

		<td nowrap><span class=lbl id="status_label" runat="server">status:</span><br>
		<asp:ListBox Rows=6 SelectionMode="Multiple" id="status" runat="server" onchange="on_change()">
		</asp:ListBox>
		</td>
	</tr>

</table>
<table border=0 cellpadding=3 cellspacing=0>
	<tr>

		<td nowrap><span class=lbl id="org_label" runat="server">organization:</span><br>
		<asp:ListBox Rows=6 SelectionMode="Multiple" id="org" runat="server" onchange="on_change()">
		</asp:ListBox>
		</td>

		<td nowrap><span class=lbl id="project_label" runat="server">project:</span><br>
			<asp:ListBox Rows=6 SelectionMode="Multiple" id="project" runat="server" onchange="set_project_changed()"
			AutoPostBack="true">
			</asp:ListBox>
		</td>

		<td nowrap><span class=lbl id="project_custom_dropdown1_label" runat="server" style="display:none">?</span><br>
			<asp:ListBox Rows=6 SelectionMode="Multiple" id="project_custom_dropdown1" runat="server" style="display:none" onchange="on_change()">
			</asp:ListBox>
		</td>
		<td nowrap><span class=lbl id="project_custom_dropdown2_label" runat="server" style="display:none">?</span><br>
			<asp:ListBox Rows=6 SelectionMode="Multiple" id="project_custom_dropdown2" runat="server" style="display:none" onchange="on_change()">
			</asp:ListBox>
		</td>
		<td nowrap><span class=lbl id="project_custom_dropdown3_label"  runat="server" style="display:none">?</span><br>
			<asp:ListBox Rows=6 SelectionMode="Multiple" id="project_custom_dropdown3" runat="server" style="display:none" onchange="on_change()">
			</asp:ListBox>
		</td>
	</tr>

</table>
<br>
<table border=0 cellpadding=3 cellspacing=0>
	<tr>
		<td><span class=lbl><% Response.Write(Util.capitalize_first_letter(Util.get_setting("SingularBugLabel","bug"))); %> description contains:&nbsp;</span>
		<td colspan=2><input type=text class=txt id="like" runat="server" onkeydown="search_criteria_onkeydown(this,event)" onkeyup="search_criteria_onkeyup(this,event)"  size=50 autocomplete="off">


		<% if (show_udf)
		{
		%>
		<td nowrap rowspan=2><span class=lbl id="udf_label" runat="server"><% Response.Write (Util.get_setting("UserDefinedBugAttributeName","YOUR ATTRIBUTE")); %></span><br>
			<asp:ListBox Rows=4 SelectionMode="Multiple" id="udf" runat="server" onchange="on_change()">
			</asp:ListBox>

		<%
		}
		%>
		</td>
	</tr>

	<tr>
		<td><span class=lbl><% Response.Write(Util.capitalize_first_letter(Util.get_setting("SingularBugLabel","bug"))); %> comments contain:&nbsp;</span>
		<td colspan=2><input type=text class=txt id="like2" runat="server" onkeyup="on_change()" size=50  autocomplete="off">
		</td>
	</tr>


	<tr>
		<td nowrap><span class=lbl><% Response.Write(Util.capitalize_first_letter(Util.get_setting("SingularBugLabel","bug"))); %> comments since:&nbsp;</span>
		<td colspan=2><input type=text class=txt id="comments_since" runat="server" onkeyup="on_change()" size=10>
			<a style="font-size: 8pt;"
			href="javascript:show_calendar('<% Response.Write(Util.get_form_name()); %>.comments_since',  null,null,'<% Response.Write(Util.get_setting("JustDateFormat",Util.get_culture_info().DateTimeFormat.ShortDatePattern)); %>');">
			[select]
			</a>
		</td>
	</tr>


	<tr>
		<td nowrap><span class=lbl>"Reported on" from date:&nbsp;</span>
		<td colspan=2><input runat="server" type=text class=txt  id="from_date" maxlength=10 size=10 onchange="on_change()">
			<a style="font-size: 8pt;"
			href="javascript:show_calendar('<% Response.Write(Util.get_form_name()); %>.from_date',  null,null,'<% Response.Write(Util.get_setting("JustDateFormat",Util.get_culture_info().DateTimeFormat.ShortDatePattern)); %>');">
			[select]
			</a>

			&nbsp;&nbsp;&nbsp;&nbsp;
			<span class=lbl>to:&nbsp;</span>
			<input runat="server" type=text class=txt  id="to_date" maxlength=10 size=10 onchange="on_change()">
			<a style="font-size: 8pt;"
			href="javascript:show_calendar('<% Response.Write(Util.get_form_name()); %>.to_date',    null,null,'<% Response.Write(Util.get_setting("JustDateFormat",Util.get_culture_info().DateTimeFormat.ShortDatePattern)); %>');">
			[select]
			</a>
		</td>
	</tr>

	<tr>
		<td  nowrap><span class=lbl>"Last updated on" from date:&nbsp;</span>
		<td colspan=2><input runat="server" type=text class=txt  id="lu_from_date" maxlength=10 size=10 onchange="on_change()">
			<a style="font-size: 8pt;"
			href="javascript:show_calendar('<% Response.Write(Util.get_form_name()); %>.lu_from_date',null,null,'<% Response.Write(Util.get_setting("JustDateFormat",Util.get_culture_info().DateTimeFormat.ShortDatePattern)); %>');">
			[select]
			</a>

			&nbsp;&nbsp;&nbsp;&nbsp;
			<span class=lbl>to:&nbsp;</span>
			<input runat="server" type=text class=txt  id="lu_to_date" maxlength=10 size=10 onchange="on_change()">
			<a style="font-size: 8pt;"
			href="javascript:show_calendar('<% Response.Write(Util.get_form_name()); %>.lu_to_date',  null,null,'<% Response.Write(Util.get_setting("JustDateFormat",Util.get_culture_info().DateTimeFormat.ShortDatePattern)); %>');">
			[select]
			</a>
		</td>
	</tr>



<%

	int minTextAreaSize = int.Parse(Util.get_setting("TextAreaThreshold","100"));
	int maxTextAreaRows = int.Parse(Util.get_setting("MaxTextAreaRows","5"));

	// Create the custom column INPUT elements
	foreach (DataRow drcc in ds_custom_cols.Tables[0].Rows)
	{

		string datatype = drcc["datatype"].ToString();
		string dropdown_type = Convert.ToString(drcc["dropdown type"]);

		Response.Write ("<tr>");
		Response.Write ("<td><span class=lbl id=\"" +  Convert.ToString(drcc["name"]) + "_label\">");
		Response.Write (drcc["name"]);

		if ((datatype == "nvarchar" || datatype == "varchar")
		&& dropdown_type == "")
		{
			Response.Write (" contains");
		}

		Response.Write (":&nbsp;</span>");

		Response.Write ("<td colspan=3>");

		int fieldLength = int.Parse(drcc["length"].ToString());

		string dropdown_options = Convert.ToString(drcc["vals"]);

		if (dropdown_type != "" || dropdown_options != "")
		{
			// create dropdown here

			Response.Write ("<select multiple=multiple size=3 onchange='on_change()' ");

			Response.Write (" id=\"" + drcc["name"].ToString() + "\"");
			Response.Write (" name=\"" + drcc["name"].ToString() + "\"");
			Response.Write (">");

			string selected_vals = Request[Convert.ToString(drcc["name"])];
			if (selected_vals == null)
			{
				selected_vals = "";
			}
			string[] selected_vals_array = Util.split_string_using_commas(selected_vals);

			if (dropdown_type != "users")
			{
				string[] options = Util.split_string_using_pipes(dropdown_options);
				for (int j = 0; j < options.Length; j++)
				{
					Response.Write ("<option ");

					// reselect vals
					for (int k = 0; k < selected_vals_array.Length; k++)
					{
						if (options[j] == selected_vals_array[k])
						{
							Response.Write (" selected ");
							break;
						}
					}

					Response.Write (">");
					Response.Write (options[j]);
					Response.Write ("</option>");
				}
			}
			else
			{
				DataView dv_users = new DataView(dt_users);
				foreach (DataRowView drv in dv_users)
				{
					string user_id = Convert.ToString(drv[0]);
					string user_name = Convert.ToString(drv[1]);

					Response.Write ("<option value=");
					Response.Write (user_id);

					// reselect vals
					for (int k = 0; k < selected_vals_array.Length; k++)
					{
						if (user_id == selected_vals_array[k])
						{
							Response.Write (" selected ");
							break;
						}
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

			Response.Write ("<input type=text class=txt");
			Response.Write ("  onkeyup=\"on_change()\" ");

			// match the size of the text field to the size of the database field

			int size = 0;

			if (datatype == "nvarchar")
			{
				size = Convert.ToInt32(drcc["length"]) / 2;
			}
			else
			{
				size = Convert.ToInt32(drcc["length"]);
			}

			if (size > 60) size = 60;
			string size_string = Convert.ToString(size);

			Response.Write (" size=" + size_string);
			Response.Write (" maxlength=" + size_string);

			Response.Write (" name=\"" + drcc["name"].ToString() + "\"");
			Response.Write (" id=\"" + drcc["name"].ToString() + "\"");

			Response.Write (" value=\"");
			if (Request[(string)drcc["name"]]!="")
			{
				Response.Write (HttpUtility.HtmlEncode(Request[(string)drcc["name"]]));
			}
			Response.Write ("\"");
			Response.Write (">");

			if ((datatype == "nvarchar" || datatype == "varchar")
			&& dropdown_type == "")
			{
				//
			}
			else
			{
				Response.Write ("&nbsp;&nbsp;<span class=smallnote>Enter multiple values using commas, no spaces: 1,2,3</span>");
			}
		}
	}
%>

	<tr>
		<td colspan=10 nowrap>
			Use "and" logic:<input type="radio" runat="server" name="and_or" value="and" id="and" onchange="on_change()" Checked>
			&nbsp;&nbsp;
			Use "or" logic:<input type="radio" runat="server" name="and_or" value="or" id="or" onchange="on_change()">
		</td>
	</tr>

	<tr>
		<td colspan=10 align=center>
			<input type=hidden runat="server" id="project_changed" value="0">
			<input type=hidden runat="server" id="hit_submit_button" value="0">
			<input type=hidden runat="server" id="hit_save_query_button" value="0">
			<input class=btn type=submit onclick="set_hit_submit_button()" value="&nbsp;&nbsp;&nbsp;Search&nbsp;&nbsp;&nbsp;" runat="server">
		</td>
	</tr>

	<tr>
		<td colspan=10 align=right>
			<script>
			function on_save_query() {
				var frm = document.getElementById("save_query_form");
				frm.sql_text.value =
					document.getElementById("visible_sql_text").innerHTML;

				frm.submit();
			}
			</script>
<% if (security.user.is_guest)  { %>
            <span style="color:Gray; font-size: 7pt;">Save Search not available to "guest" user</span>
<% } else { %>
			<input class=btn type=submit onclick="on_save_query()" value="Save search criteria as query">
<% } %>
		</td>
	</tr>

</table>

<!-- #include file = "inc_bugs2.inc" -->

<input type=hidden id="query" runat="server" value="">
</form>
</div>

</td></tr></table></div>

<%
if (dv == null)
{

}
else
{
	if (dv.Table.Rows.Count > 0)
	{

		Response.Write ("<a target=_blank href=print_bugs.aspx>print list</a>");
		Response.Write ("&nbsp;&nbsp;&nbsp;<a target=_blank href=print_bugs2.aspx>print detail</a>");
		Response.Write ("&nbsp;&nbsp;&nbsp;<a target=_blank href=print_bugs.aspx?format=excel>export to excel</a><br>");

		if (security.user.is_admin || security.user.can_mass_edit_bugs)
		{
			Response.Write ("<form id=massform onsubmit='return validate_mass()' method=get action=massedit.aspx>");
			display_bugs(true);
			Response.Write("<p><table class=frm><tr><td colspan=5 class=smallnote>Update or delete all checked items");
			Response.Write("<tr><td colspan=5>");
			Response.Write("<a href=javascript:select_all(true)>select all</a>&nbsp;&nbsp;&nbsp;&nbsp;");
			Response.Write("<a href=javascript:select_all(false)>deselect all</a>");
			Response.Write("<tr>");
			Response.Write("<td><span class=lbl>project:</span><br><select name=mass_project id=mass_project></select>");
			Response.Write("<td><span class=lbl>organization:</span><br><select name=mass_org id=mass_org></select>");
			Response.Write("<td><span class=lbl>category:</span><br><select name=mass_category id=mass_category></select>");
			Response.Write("<td><span class=lbl>priority:</span><br><select name=mass_priority id=mass_priority></select>");
			Response.Write("<td><span class=lbl>assigned to:</span><br><select name=mass_assigned_to id=mass_assigned_to></select>");
			Response.Write("<td><span class=lbl>status:</span><br><select name=mass_status id=mass_status></select>");
			Response.Write("<tr><td colspan=5>OR DELETE:&nbsp;<input type=checkbox class=cb name=mass_delete>");
			Response.Write("<tr><td colspan=5 align=center><input type=submit value='Update/Delete All'>");
			Response.Write("</table></form><p><script>load_massedit_selects()</script>");
		}
		else
		{
			// no checkboxes
			display_bugs(false);
		}


	}
	else
	{
		Response.Write ("<p>No ");
		Response.Write (Util.get_setting("PluralBugLabel","bug"));
		Response.Write ("<p>");
	}
}
%>

<p>
<span id="visible_sql_label" runat="server">SQL:</span>
</p>
<pre style="font-family: courier new; font-size: 8pt" id="visible_sql_text" runat="server">&nbsp;</pre>

<!-- form 3 -->
<form id="save_query_form" target="_blank" method="post" action="edit_query.aspx">
<input type="hidden" name="sql_text" value="">
</form>

<% Response.Write(Application["custom_footer"]); %></body>
</html>