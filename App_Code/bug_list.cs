/*
Copyright 2002-2008 Corey Trager
Distributed under the terms of the GNU General Public License
*/

using System;
using System.Web;
using System.Data;
//using System.Data.SqlClient;
using System.Collections.Specialized;
using System.IO;
using System.Text.RegularExpressions;
using System.Collections.Generic;

namespace btnet
{

	public class BugList {

        static string get_distinct_vals_from_dataset(DataTable dt, int col)
        {
            SortedDictionary<string, int> dict = new SortedDictionary<string, int>();

            foreach (DataRow row in dt.Rows)
            {
                dict[Convert.ToString(row[col])] = 1;
            }

            string vals = "";

            foreach (string s in dict.Keys)
            {
                if (vals != "") vals += "|";

                vals += s;
            }

            return vals;
        }


        ///////////////////////////////////////////////////////////////////////
        static string get_buglist_bug_count_string(DataView dv)
        {
            if (dv.Count == dv.Table.Rows.Count)
            {
                return "<br><br>"
                    + Convert.ToString(dv.Table.Rows.Count)
                    + " "
                    + btnet.Util.get_setting("PluralBugLabel", "bugs")
                    + " returned by query<br>";
            }
            else
            {
                return "<br><br>"
                    + "Showing "
                    + Convert.ToString(dv.Count)
                    + " out of "
                    + Convert.ToString(dv.Table.Rows.Count)
                    + " "
                    + btnet.Util.get_setting("PluralBugLabel", "bugs")
                    + " returned by query<br>";
            }
        }

        ///////////////////////////////////////////////////////////////////////
        static string get_buglist_paging_string(DataView dv, Security security, bool IsPostBack, string new_page, ref int this_page)
        {

            // format the text "page N of N:  1 2..."
            this_page = 0;
            if (IsPostBack)
            {
                this_page = Convert.ToInt32(new_page);
                HttpContext.Current.Session["page"] = this_page;
            }
            else
            {
                if (HttpContext.Current.Session["page"] != null)
                {
                    this_page = (int)HttpContext.Current.Session["page"];
                }
            }

            // how many pages to show all the rows?
            int total_pages = (dv.Count - 1) / security.user.bugs_per_page + 1;

            if (this_page > total_pages - 1)
            {
                this_page = 0;
                HttpContext.Current.Session["page"] = this_page;
            }

            string paging_string = "";

            if (total_pages > 1)
            {

                // The "<"
                if (this_page > 0)
                {
                    paging_string += "<a href='javascript: on_page("
                        + Convert.ToString(this_page - 1)
                        + ")'><b>&nbsp;&lt&lt&nbsp;</b></a>&nbsp;";
                }


                // first page is "0", second page is "1", so add 1 for display purposes
                paging_string += "page&nbsp;"
                    + Convert.ToString(this_page + 1)
                    + "&nbsp;of&nbsp;"
                    + Convert.ToString(total_pages)
                    + "&nbsp;";

                // The ">"
                if (this_page < total_pages - 1)
                {
                    paging_string += "<a href='javascript: on_page("
                        + Convert.ToString(this_page + 1)
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


                for (int i = left; i < right; i++)
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
                    + Convert.ToString(total_pages - 1)
                    + ")'>[last]</a>";
                }

            }

            return paging_string;
        }

        ///////////////////////////////////////////////////////////////////////
        public static void sort_and_filter_buglist_dataview(DataView dv, bool IsPostBack,
            string actn_val,
            ref string filter_val,
            ref string sort_val,
            ref string prev_sort_val,
            ref string prev_dir_val)
        {

            if (dv == null) return;

            // remember filter
            if (!IsPostBack)
            {
                if (HttpContext.Current.Session["filter"] != null)
                {
                    filter_val = (string)HttpContext.Current.Session["filter"];
                    try
                    {
                        dv.RowFilter = filter_val.Replace("'", "''").Replace("$$$", "'");
                    }
                    catch (Exception)
                    {
                        // just in case a filter in the Session is incompatible
                    }
                }
            }
            else
            {

                HttpContext.Current.Session["filter"] = filter_val;
                string filter_string = filter_val;

                filter_string = filter_string.Replace("[$FLAG] =$$$red$$$", "[$FLAG] =1");
                filter_string = filter_string.Replace("[$FLAG] =$$$green$$$", "[$FLAG] =2");
                filter_string = filter_string.Replace("[$FLAG]<>$$$$$$", "[$FLAG] <>0");
                filter_string = filter_string.Replace("[$FLAG] =$$$$$$", "[$FLAG] =0");

                filter_string = filter_string.Replace("[$SEEN] =$$$no$$$", "[$SEEN] =1");
                filter_string = filter_string.Replace("[$SEEN] =$$$yes$$$", "[$SEEN] =0");

                try
                {
                    string filter_string2 = filter_string.Replace("'", "''").Replace("$$$", "'");
                    if (HttpContext.Current.Request["tags"] != null && HttpContext.Current.Request["tags"] != "")
                    {
                        filter_string2 += btnet.Tags.build_filter_clause(
                            HttpContext.Current.Application,
                            HttpContext.Current.Request["tags"]);
                    }

                    dv.RowFilter = filter_string2;
                }
                catch (Exception)
                {
                    // just in case a filter in the Session is incompatible
                }
            }



            // Determine which column to sort
            // and toggle ASC  DESC

            if (actn_val == "sort")
            {
                int sort_column = Convert.ToInt32(sort_val) + 1;
                string sort_expression = dv.Table.Columns[sort_column].ColumnName;
                if (sort_val == prev_sort_val)
                {
                    if (prev_dir_val == "ASC")
                    {
                        prev_dir_val = "DESC";
                        sort_expression += " DESC";
                    }
                    else
                    {
                        prev_dir_val = "ASC";
                    }
                }
                else
                {
                    prev_sort_val = sort_val;
                    prev_dir_val = "ASC";
                }
                dv.Sort = sort_expression;
                HttpContext.Current.Session["sort"] = sort_expression;
            }
            else
            {
                // remember sort
                if (!IsPostBack)
                {
                    if (HttpContext.Current.Session["sort"] != null)
                    {
                        try
                        {
                            dv.Sort = (string)HttpContext.Current.Session["sort"];
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
        static void display_buglist_filter_select(
            HttpResponse Response,
            string filter_val,
            string which,
            System.Data.DataTable table,
            string dropdown_vals,
            int col)
        {

            // determine what the selected item in the dropdown should be

            string selected_value = "[no filter]";
            string op = " =";
            bool something_selected = false;

            if (filter_val.IndexOf("66 = 66") > -1)
            {
                int pos = filter_val.IndexOf(which);
                if (pos != -1)
                {
                    // move past the variable
                    pos += which.Length;
                    pos += 5;  // to move past the " =$$$" and the single quote
                    int pos2 = filter_val.IndexOf("$$$", pos);  // find the trailing $$$
                    selected_value = filter_val.Substring(pos, pos2 - pos);
                    op = filter_val.Substring(pos - 5, 2);
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

            // at this point we have the selected value

            if (selected_value == "[no filter]")
            {
                Response.Write("<select class=filter ");
            }
            else
            {
                Response.Write("<select class=filter_selected ");
            }


            Response.Write(" id='sel_" + which + "' onchange='on_filter()'>");
            Response.Write("<option>[no filter]</option>");

            if (which != "[$SEEN]")
            {
                if (selected_value == "[none]")
                {
                    Response.Write("<option selected value=''>[none]</option>");
                    something_selected = true;
                }
                else
                {
                    Response.Write("<option value=''>[none]</option>");
                }
            }

            if (which != "[$SEEN]")
            {
                if (selected_value == "[any]")
                {
                    Response.Write("<option selected value=''>[any]</option>");
                    something_selected = true;
                }
                else
                {
                    Response.Write("<option value=''>[any]</option>");
                }
            }

            if (dropdown_vals != null)
            {
                string[] options = Util.split_string_using_pipes(dropdown_vals);
                for (int i = 0; i < options.Length; i++)
                {

                    if (selected_value == options[i])
                    {
                        Response.Write("<option selected>" + options[i] + "</option>");
                        something_selected = true;
                    }
                    else
                    {
                        Response.Write("<option>" + options[i] + "</option>");
                    }
                }
            }
            else
            {
                foreach (DataRow dr in table.Rows)
                {
                    if (selected_value == Convert.ToString(dr[col]))
                    {
                        Response.Write("<option selected>" + Convert.ToString(dr[col]) + "</option>");
                        something_selected = true;
                    }
                    else
                    {
                        Response.Write("<option>" + Convert.ToString(dr[col]) + "</option>");
                    }
                }
            }


            if (!something_selected)
            {
                if (selected_value != "[no filter]")
                {
                    Response.Write("<option selected>" + selected_value + "</option>");
                }
            }

            Response.Write("</select>");

        }

        ///////////////////////////////////////////////////////////////////////
        public static void display_buglist_tags_line(HttpResponse Response, Security security)
        {
            if (security.user.category_field_permission_level == Security.PERMISSION_NONE)
            {
                return;
            }

            Response.Write("\n<p>Show only rows with the following tags:&nbsp;");
            Response.Write("<input class=txt size=40 name=tags_input id=tags_input onchange='javascript:on_tags_change()' value='");
            Response.Write(HttpContext.Current.Request["tags"]);
            Response.Write("'>");
            Response.Write("<a href='javascript:show_tags()'>&nbsp;&nbsp;select tags</a>");
            Response.Write("<br><br>\n");
        }
        ///////////////////////////////////////////////////////////////////////
        static void display_filter_select(HttpResponse Response, string filter_val, string which, System.Data.DataTable table)
        {
            display_buglist_filter_select(
            Response,
            filter_val,
            which,
            table,
            null,
            0);
        }

        ///////////////////////////////////////////////////////////////////////
        static void display_filter_select(HttpResponse Response, string filter_val, string which, System.Data.DataTable table, int col)
        {
            display_buglist_filter_select(
            Response,
            filter_val,
            which,
            table,
            null,
            col);
        }


        ///////////////////////////////////////////////////////////////////////
        static void display_filter_select(HttpResponse Response, string filter_val, string which, string dropdown_vals)
        {
            display_buglist_filter_select(
            Response,
            filter_val,
            which,
            null,
            dropdown_vals,
            0);
        }


        ///////////////////////////////////////////////////////////////////////
        public static void display_bugs(
            bool show_checkbox,
            DataView dv,
            HttpResponse Response,
            Security security,
            string new_page_val,
            bool IsPostBack,
            DataSet ds_custom_cols,
            DbUtil dbutil,
            string filter_val
            )
        {
            int this_page = 0;
            string paging_string = get_buglist_paging_string(
                dv,
                security,
                IsPostBack,
                new_page_val,
                ref this_page);

            string bug_count_string = get_buglist_bug_count_string(dv);

            Response.Write(paging_string);
            Response.Write("<table class=bugt border=1 ><tr>\n");

            ///////////////////////////////////////////////////////////////////
            // headings
            ///////////////////////////////////////////////////////////////////

            int db_column_count = 0;
            int description_column = -1;
            int search_desc_column = -1;
            int search_text_column = -1;

            foreach (DataColumn dc in dv.Table.Columns)
            {

                if (db_column_count == 0)
                {
                    // skip color/style

                    if (show_checkbox)
                    {
                        Response.Write("<td class=bugh><font size=0>sel</font>");
                    }
                }
                else if (dc.ColumnName == "$SCORE")
                {
                    // don't display the score, but the "union" and "order by" in the
                    // query forces us to include it as one of the columns
                }
                else
                {

                    Response.Write("<td class=bugh>\n");
                    // sorting
                    string s = "<a href='javascript: on_sort($col)'>";
                    s = s.Replace("$col", Convert.ToString(db_column_count - 1));
                    Response.Write(s);

                    if (dc.ColumnName == "$FLAG")
                    {
                        Response.Write("flag");
                    }
                    else if (dc.ColumnName == "$SEEN")
                    {
                        Response.Write("new");
                    }
                    else if (dc.ColumnName.ToLower().IndexOf("desc") == 0)
                    {
                        // remember this column so that we can make it a link
                        description_column = db_column_count; // zero based here
                        Response.Write(dc.ColumnName);
                    }
                    else if (dc.ColumnName == "search_desc")
                    {
                        search_desc_column = db_column_count;
                        Response.Write("desc");
                    }
                    else if (dc.ColumnName == "search_text")
                    {
                        search_text_column = db_column_count;
                        Response.Write("comment/email text");
                    }
                    else
                    {
                        Response.Write(dc.ColumnName);
                    }

                    Response.Write("</a>");
                    Response.Write("</td>\n");

                }

                db_column_count++;

            }

            Response.Write("</tr>\n<tr>");

            ////////////////////////////////////////////////////////////////////
            /// filter row
            ////////////////////////////////////////////////////////////////////

            if (ds_custom_cols == null)
            {
                ds_custom_cols = Util.get_custom_columns(dbutil);
            }

            db_column_count = 0;
            string udf_column_name = Util.get_setting("UserDefinedBugAttributeName", "YOUR ATTRIBUTE");

            foreach (DataColumn dc in dv.Table.Columns)
            {

                // skip color
                if (db_column_count == 0)
                {
                    if (show_checkbox)
                    {
                        Response.Write("<td class=bugf>&nbsp;</td>");
                    }
                }
                else if (dc.ColumnName == "$SCORE")
                {
                    // skip
                }
                else
                {
                    Response.Write("<td class=bugf> ");

                    if (dc.ColumnName == "$FLAG")
                    {
                        display_filter_select(Response, filter_val, "[$FLAG]", "red|green");
                    }
                    else if (dc.ColumnName == "$SEEN")
                    {
                        display_filter_select(Response, filter_val, "[$SEEN]", "yes|no");
                    }
                    else if (dc.ColumnName == "project"
                    || dc.ColumnName == "organization"
                    || dc.ColumnName == "category"
                    || dc.ColumnName == "priority"
                    || dc.ColumnName == "status"
                    || dc.ColumnName == "reported by"
                    || dc.ColumnName == "assigned to"
                    || dc.ColumnName == "assigned to"
                    || dc.ColumnName == udf_column_name)
                    {
                        string string_vals = get_distinct_vals_from_dataset(
                            (DataTable)HttpContext.Current.Session["bugs_unfiltered"],
                            db_column_count);

                        display_filter_select(
                            Response,
                            filter_val,
                            "[" + dc.ColumnName + "]",
                            string_vals);
                    }
                    else
                    {
                        bool with_filter = false;
                        foreach (DataRow drcc in ds_custom_cols.Tables[0].Rows)
                        {
                            if (dc.ColumnName == (string)drcc["name"])
                            {
                                if ((string)drcc["dropdown type"] == "normal"
                                || (string)drcc["dropdown type"] == "users")
                                {
                                    with_filter = true;

                                    string string_vals = get_distinct_vals_from_dataset(
                                        (DataTable)HttpContext.Current.Session["bugs_unfiltered"],
                                        db_column_count);

                                    display_filter_select(
                                        Response,
                                        filter_val,
                                        "[" + (string)drcc["name"] + "]",
                                        string_vals);
                                }

                                break;
                            }
                        }

                        if (!with_filter)
                        {
                            Response.Write("&nbsp");
                        }
                    }

                    Response.Write("</td>\n");
                }

                db_column_count++;

            }

            Response.Write("</tr>\n");

            string class_or_color = "class=bugd";
            string col_one;



            ///////////////////////////////////////////////////////////////////
            // data
            ///////////////////////////////////////////////////////////////////
            int rows_this_page = 0;
            int j = 0;

            foreach (DataRowView drv in dv)
            {

                // skip over rows prior to this page
                if (j < security.user.bugs_per_page * this_page)
                {
                    j++;
                    continue;
                }


                // do not show rows beyond this page
                rows_this_page++;
                if (rows_this_page > security.user.bugs_per_page)
                {
                    break;
                }


                DataRow dr = drv.Row;

                Response.Write("<tr>");

                if (show_checkbox)
                {
                    Response.Write("<td class=bugd><input type=checkbox name=");
                    Response.Write(Convert.ToString(dr[1]));
                    Response.Write(">");
                }

                for (int i = 0; i < dv.Table.Columns.Count; i++)
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

                        if (dv.Table.Columns[i].ColumnName == "$SCORE")
                        {
                            // skip
                        }
                        else if (dv.Table.Columns[i].ColumnName == "$FLAG")
                        {
                            int flag = (int)dr[i];
                            string cls = "wht";
                            if (flag == 1) cls = "red";
                            else if (flag == 2) cls = "grn";

                            Response.Write("<td class=bugd align=center><span class="
                                + cls
                                + " onclick='flag(this, "
                                + Convert.ToString(dr[1])
                                + ")'>&nbsp;</span></td>");
                        }
                        else if (dv.Table.Columns[i].ColumnName == "$SEEN")
                        {
                            int seen = (int)dr[i];
                            string cls = "old";
                            if (seen == 0)
                            {
                                cls = "new";
                            }
                            else
                            {
                                cls = "old";
                            }

                            Response.Write("<td class=bugd align=center><span class="
                                + cls
                                + " onclick='seen(this, "
                                + Convert.ToString(dr[1])
                                + ")'>&nbsp;</span></td>");
                        }
                        else
                        {

                            string datatype = dv.Table.Columns[i].DataType.ToString();

                            if (Util.is_numeric_datatype(datatype))
                            {
                                Response.Write("<td " + class_or_color + " align=right>");
                            }
                            else
                            {
                                Response.Write("<td " + class_or_color + " >");
                            }

                            // write the data
                            if (dr[i].ToString() == "")
                            {
                                Response.Write("&nbsp;");
                            }
                            else
                            {
                                if (datatype == "System.DateTime")
                                {
                                    Response.Write(Util.format_db_date(dr[i]));
                                }
                                else
                                {
                                    if (i == description_column)
                                    {
                                        // write description as a link
                                        Response.Write("<a onmouseover=on_mouse_over(this) onmouseout=on_mouse_out() href=edit_bug.aspx?id="
                                            + Convert.ToString(dr[1]) + ">");
                                        Response.Write(HttpContext.Current.Server.HtmlEncode(dr[i].ToString()));
                                        Response.Write("</a>");
                                    }
                                    else if (i == search_desc_column)
                                    {
                                        // write description as a link
                                        Response.Write("<a onmouseover=on_mouse_over(this) onmouseout=on_mouse_out() href=edit_bug.aspx?id="
                                        + Convert.ToString(dr[1]) + ">");
                                        Response.Write(dr[i].ToString()); // already encoded
                                        Response.Write("</a>");
                                    }
                                    else if (i == search_text_column)
                                    {
                                        Response.Write(dr[i].ToString()); // already encoded
                                    }
                                    else
                                    {
                                        Response.Write(HttpContext.Current.Server.HtmlEncode(dr[i].ToString()).Replace("\n", "<br>"));
                                    }
                                }
                            }
                        }

                        Response.Write("</td>");

                    }
                }

                Response.Write("</tr>\n");

                j++;
            }

            Response.Write("</table>");
            Response.Write(paging_string);
            Response.Write(bug_count_string);
        }

	}
}	
	