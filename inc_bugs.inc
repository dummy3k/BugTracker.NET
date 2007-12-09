<script language="C#" runat="server">
string sql;
System.Data.DataView dv;
int page_size;
int this_page=0;
int total_rows;
int start_row;
System.Data.DataSet ds_filters;
System.Data.DataSet ds_custom_cols;

///////////////////////////////////////////////////////////////////////
string get_paging_string()
{

	// format the text "page N of N:  1 2..."
	this_page=0;
	if (IsPostBack)
	{
		this_page = Convert.ToInt32(new_page.Value);
		Session["page"] = this_page;
	}
	else
	{
		if (Session["page"] != null)
		{
			this_page = (int) Session["page"];
		}
	}
	
	
	page_size = security.this_bugs_per_page; 
	total_rows = dv.Count;
	// how many pages to show all the rows?
	int total_pages = (total_rows-1) / page_size + 1;

	if (this_page > total_pages -1)
	{
		this_page = 0;
		Session["page"] = this_page;
	}
	
	start_row = this_page * page_size;

	string paging_string = "";

	if (total_pages > 1)
	{

		// The "<"
		if (this_page > 0)
		{
			paging_string += "<a href='javascript: on_page("
				+ Convert.ToString(this_page-1)
				+ ")'><b>&nbsp;&lt&lt&nbsp;</b></a>&nbsp;";
		}


		// first page is "0", second page is "1", so add 1 for display purposes
		paging_string += "page&nbsp;"
			+ Convert.ToString(this_page + 1)
			+ "&nbsp;of&nbsp;"
			+ Convert.ToString(total_pages)
			+ "&nbsp;";

		// The ">"
		if (this_page < total_pages-1)
		{
			paging_string += "<a href='javascript: on_page("
				+ Convert.ToString(this_page+1)
				+ ")'><b>&nbsp;&gt;&gt;&nbsp;</b></a>";
		}

		paging_string += "&nbsp;&nbsp;&nbsp;";

		int left = this_page - 16;
		if (left < 1)
		{
			left = 0;
		}
		else
		{
			paging_string += "<a href='javascript: on_page(0)'>[first]</a>...&nbsp;";
		}

		int right = left + 32;
		if (right > total_pages)
		{
			right = total_pages;
		}


		for (int i = left;i < right; i++)
		{
			if (this_page == i)
			{
				paging_string += "[" + Convert.ToString(i + 1) + "]&nbsp;";
			}
			else
			{
				paging_string += "<a href='javascript: on_page("
					+ Convert.ToString(i)
					+ ")'>"
					+ Convert.ToString(i + 1)
					+ "</a>&nbsp;";
			}
		}

		if (right < total_pages)
		{
			paging_string += "&nbsp;...<a href='javascript: on_page("
			+ Convert.ToString(total_pages-1)
			+ ")'>[last]</a>";
		}

	}

	return paging_string;
}


///////////////////////////////////////////////////////////////////////
void sort_dataview() {

	// remember filter
	if (!IsPostBack)
	{
		if (Session["filter"] != null)
		{
			filter.Value = (string) Session["filter"];
			try
			{
				dv.RowFilter = filter.Value.Replace("'","''").Replace("$$$","'");
			}
			catch(Exception)
			{
				// just in case a filter in the Session is incompatible
			}
		}
	}
	else
	{
		Session["filter"] = filter.Value;
		dv.RowFilter = filter.Value.Replace("'","''").Replace("$$$","'");
	}
	
	
	
	// Determine which column to sort
	// and toggle ASC  DESC

	if (action.Value == "sort") {
		int sort_column = Convert.ToInt32(sort.Value) + 1;
		string sort_expression = dv.Table.Columns[sort_column].ColumnName;
		if (sort.Value == prev_sort.Value) {
			if (prev_dir.Value == "ASC") {
				prev_dir.Value = "DESC";
				sort_expression += " DESC";
			}
			else {
				prev_dir.Value = "ASC";
			}
		}
		else {
			prev_sort.Value = sort.Value;
			prev_dir.Value = "ASC";
		}
		dv.Sort = sort_expression;
		Session["sort"] = sort_expression;
	}
	else
	{
		// remember sort
		if (!IsPostBack)
		{
			if (Session["sort"] != null)
			{
				try
				{
					dv.Sort = (string) Session["sort"];
				}
				catch (Exception)
				{
					// just in case a sort stored in Session is incompatible				
				}
			}
		}
	}
}


///////////////////////////////////////////////////////////////////////
void display_bugs()
{
	display_bugs (false);
}

///////////////////////////////////////////////////////////////////////
void display_filter_select(string which, System.Data.DataTable table)
{
	display_filter_select(which, table, null, 0);
}

///////////////////////////////////////////////////////////////////////
void display_filter_select(string which, System.Data.DataTable table, int col)
{
	display_filter_select(which, table, null, col);
}


///////////////////////////////////////////////////////////////////////
void display_filter_select(string which, string dropdown_vals)
{
	display_filter_select(which, null, dropdown_vals, 0);
}



///////////////////////////////////////////////////////////////////////
void display_filter_select(string which, System.Data.DataTable table, string dropdown_vals, int col)
{

	// determine what the selected item in the dropdown should be

	string selected_value = "[no filter]";
	string op = " =";

	if (filter.Value.IndexOf("66 = 66") > -1)
	{
		int pos = filter.Value.IndexOf(which);
		if (pos != -1)
		{
			// move past the variable
			pos += which.Length;
			pos += 5;  // to move past the " =$$$" and the single quote
			int pos2 = filter.Value.IndexOf("$$$",pos);  // find the trailing $$$
			selected_value = filter.Value.Substring(pos, pos2-pos);
			op = filter.Value.Substring(pos-5,2);
		}
	}


	if (selected_value == "")
	{
		if (op == " =")
		{
			selected_value = "[none]";
		}
		else
		{
			selected_value = "[any]";
		}
	}

	if (selected_value == "[no filter]")
	{
		Response.Write ("<select class=filter ");
	}
	else
	{
		Response.Write ("<select class=filter_selected ");
	}


	Response.Write (" id='sel_" + which + "' onchange='on_filter()'>");
	Response.Write ("<option>[no filter]</option>");

	if (selected_value == "[none]")
	{
		Response.Write ("<option selected value=''>[none]</option>");
	}
	else
	{
		Response.Write ("<option value=''>[none]</option>");
	}


	if (selected_value == "[any]")
	{
		Response.Write ("<option selected value=''>[any]</option>");
	}
	else
	{
		Response.Write ("<option value=''>[any]</option>");
	}

	if (dropdown_vals != null)
	{
		string[] options = Util.split_string_using_pipes(dropdown_vals);
		for (int i = 0; i < options.Length; i++)
		{

			if (selected_value == options[i])
			{
				Response.Write ("<option selected>" + options[i] + "</option>");
			}
			else
			{
				Response.Write ("<option>" + options[i] + "</option>");
			}
		}
	}
	else
	{
		foreach (DataRow dr in table.Rows)
		{
			if (selected_value == Convert.ToString(dr[col]))
			{
				Response.Write ("<option selected>" + Convert.ToString(dr[col]) + "</option>");
			}
			else
			{
				Response.Write ("<option>" + Convert.ToString(dr[col]) + "</option>");
			}
		}
	}

	Response.Write ("</select>");

}


///////////////////////////////////////////////////////////////////////
void display_bugs(bool show_checkbox)
{
	
	if (dt_users == null)
	{
		dt_users = Util.get_related_users(security, dbutil);
	}

	string paging_string = get_paging_string();

	Response.Write (paging_string);
	Response.Write ("<table class=bugt border=1 ><tr>\n");

	///////////////////////////////////////////////////////////////////
	// headings
	///////////////////////////////////////////////////////////////////

	int db_column_count = 0;
	int description_column = -1;

	{
	foreach (DataColumn dc in dv.Table.Columns)
	{

		if (db_column_count == 0)
		{
			// skip color/style
			
			if (show_checkbox)
			{
				Response.Write ("<td class=bugh><font size=0>sel</font>");
			}
		}
		else
		{

			Response.Write ("<td class=bugh>\n");
			// sorting
			string s = "<a href='javascript: on_sort($col)'>";
			s = s.Replace("$col", Convert.ToString(db_column_count-1));
			Response.Write (s);
			
			if (dc.ColumnName == "$FLAG")
			{
				Response.Write ("[!]");
			}
			else
			{
				Response.Write (dc.ColumnName);
			}
			
			Response.Write ("</a>");

			if (dc.ColumnName.ToLower().IndexOf("desc") == 0) {
				// remember this column so that we can make it a link
				description_column = db_column_count; // zero based here
			}

			Response.Write ("</td>\n");

		}

		db_column_count++;

	}}

	Response.Write ("</tr>\n<tr>");

	////////////////////////////////////////////////////////////////////
	/// filter row
	////////////////////////////////////////////////////////////////////

	// do the queries for the html SELECT elements

	string sql = @"/* for dropdowns, filters */
			select pj_name
			from projects
			left outer join project_user_xref on pj_id = pu_project
			and pu_user = $us
			where pj_active = 1
			and isnull(pu_permission_level,$dpl) <> 0
			order by pj_name;";

	sql = sql.Replace("$us",Convert.ToString(security.this_usid));
	sql = sql.Replace("$dpl", Util.get_setting("DefaultPermissionLevel","2"));

	if (security.this_other_orgs_permission_level != 0)
	{
		sql += "select og_name from orgs order by og_name;";
	}
	else
	{
		sql += "select og_name from orgs where og_id = " + Convert.ToInt32(security.this_org);
	}
	sql += @"
select ct_name from categories order by ct_sort_seq, ct_name;
select pr_name from priorities order by pr_sort_seq, pr_name
select st_name from statuses order by st_sort_seq, st_name
select udf_name from user_defined_attribute order by udf_sort_seq, udf_name";

	ds_filters = dbutil.get_dataset(sql);

	if (ds_custom_cols == null)
	{
		ds_custom_cols = Util.get_custom_columns(dbutil);
	}

	db_column_count = 0;
	string udf_column_name = Util.get_setting("UserDefinedBugAttributeName","YOUR ATTRIBUTE");

	{
	foreach (DataColumn dc in dv.Table.Columns)
	{

		// skip color
		if (db_column_count == 0)
		{
			if (show_checkbox)
			{
				Response.Write ("<td class=bugf>&nbsp;</td>");
			}
		}
		else
		{
			Response.Write ("<td class=bugf>");

			if (dc.ColumnName == "project")
			{
				display_filter_select ("[project]", ds_filters.Tables[0]);
			}
			else if (dc.ColumnName == "organization")
			{
				display_filter_select ("[organization]", ds_filters.Tables[1]);
			}
			else if (dc.ColumnName == "category")
			{
				display_filter_select ("[category]", ds_filters.Tables[2]);
			}
			else if (dc.ColumnName == "priority")
			{
				display_filter_select ("[priority]", ds_filters.Tables[3]);
			}
			else if (dc.ColumnName == "status")
			{
				display_filter_select ("[status]", ds_filters.Tables[4]);
			}
			else if (dc.ColumnName == udf_column_name)
			{
				display_filter_select ("[" + udf_column_name + "]", ds_filters.Tables[5]);
			}
			else if (dc.ColumnName == "reported by")
			{
				display_filter_select ("[reported by]", dt_users, 1);
			}
			else if (dc.ColumnName == "assigned to")
			{
				DataView dv_users = new DataView(dt_users);
				display_filter_select ("[assigned to]", dt_users, 1);
			}
			else
			{
				bool with_filter = false;
				foreach (DataRow drcc in ds_custom_cols.Tables[0].Rows)
				{
					if (dc.ColumnName == (string) drcc["name"])
					{
						if ((string)drcc["dropdown type"] == "normal")
						{
							with_filter = true;
							display_filter_select ("[" + (string) drcc["name"] + "]",
								Convert.ToString(drcc["vals"]));
						}
						else if ((string)drcc["dropdown type"] == "users")
						{
							with_filter = true;
							display_filter_select ("[" + (string) drcc["name"] + "]", dt_users, 1);
						}
						else
						{
							break;
						}
					}
				}

				if (!with_filter)
				{
					Response.Write ("&nbsp");
				}
			}
			Response.Write ("</td>\n");
		}

		db_column_count++;

	}}

	Response.Write ("</tr>\n");

	string class_or_color = "class=bugd";
	string col_one;



	///////////////////////////////////////////////////////////////////
	// data
	///////////////////////////////////////////////////////////////////
	int rows_this_page = 0;
	int j = 0;

	//for (int j = (page_size * this_page); j < total_rows; j++)
	foreach (DataRowView drv in dv)
	{

		// skip over rows prior to this page
		if (j < page_size * this_page) {
			j++;
			continue;
		}


		// do not show rows beyond this page
		rows_this_page++;
		if (rows_this_page > page_size)
		{
			break;
		}


		DataRow dr = drv.Row;

		Response.Write ("<tr>");

		if (show_checkbox)
		{
			Response.Write ("<td class=bugd><input type=checkbox name=");
			Response.Write (Convert.ToString(dr[1]));
			Response.Write (">");
		}

		for(int i = 0; i < dv.Table.Columns.Count; i++)
		{

			if (i == 0)
			{
				col_one = Convert.ToString(dr[0]);

				if (col_one == "")
				{
					class_or_color = "class=bugd";
				}
				else
				{
					if (col_one[0] == '#')
					{
						class_or_color = "class=bugd bgcolor=" + col_one;
					}
					else
					{
						class_or_color = "class=\"" + col_one + "\"";
					}
				}
			}
			else
			{

				if (dv.Table.Columns[i].ColumnName == "$FLAG")
				{
					int flag = (int) dr[i];
					string cls = "wht";
					if (flag == 1) cls = "red";
					else if (flag == 2) cls = "grn";
					
					Response.Write("<td class=bugd><span class=" 
						+ cls 
						+ " onclick='flag(this, " 
						+ Convert.ToString(dr[1])
						+ ")'></span></td>");
				}
				else
				{
				
					string datatype = dv.Table.Columns[i].DataType.ToString();

					if (Util.is_numeric_datatype(datatype))
					{
						Response.Write ("<td "  + class_or_color + " align=right>");
					}
					else
					{
						Response.Write ("<td " + class_or_color + " >");
					}

					// write the data
					if (dr[i].ToString() == "")
					{
						Response.Write ("&nbsp;");
					}
					else
					{
						if (datatype == "System.DateTime")
						{
							Response.Write (Util.format_db_date(dr[i]));
						}
						else
						{
							if (i == description_column)
							{
								// write description as a link
								Response.Write ("<a onmouseover=on_mouse_over(this) onmouseout=on_mouse_out() href=edit_bug.aspx?id="
									+ Convert.ToString(dr[1]) + ">");
								Response.Write (Server.HtmlEncode(dr[i].ToString()));
								Response.Write ("</a>");
							}
							else
							{
								Response.Write (Server.HtmlEncode(dr[i].ToString()).Replace("\n","<br>"));
							}
						}
					}
				}

				Response.Write ("</td>");

			}
		}

		Response.Write ("</tr>\n");

		j++;
	}

	Response.Write ("</table>");
	Response.Write (paging_string);

}

</script>