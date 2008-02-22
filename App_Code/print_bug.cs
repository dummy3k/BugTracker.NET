/*
Copyright 2002-2008 Corey Trager
Distributed under the terms of the GNU General Public License
*/

using System;
using System.Web;
using System.Data;
using System.Text.RegularExpressions;

namespace btnet
{

	public class PrintBug {

        static Regex reEmail = new Regex(
                @"([a-zA-Z0-9_\-\.]+)@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\."
                + @")|(([a-zA-Z0-9\-]+\.)+))([a-zA-Z]{2,4}|[0-9]{1,3})",
                RegexOptions.IgnoreCase
                | RegexOptions.CultureInvariant
                | RegexOptions.IgnorePatternWhitespace
                | RegexOptions.Compiled);

        // convert URL's to hyperlinks
        static Regex reHyperlinks = new Regex(
                @"(?<Protocol>\w+):\/\/(?<Domain>[\w.]+\/?)\S*",
                RegexOptions.IgnoreCase
                | RegexOptions.CultureInvariant
                | RegexOptions.IgnorePatternWhitespace
                | RegexOptions.Compiled);


		///////////////////////////////////////////////////////////////////////
		public static void print_bug (HttpResponse Response, DataRow dr, bool this_is_admin, bool this_external_user, bool include_style)
		{

			int bugid = Convert.ToInt32(dr["id"]);
			string string_bugid = Convert.ToString(bugid);

            if (include_style)
            {
                Response.Write("\n<style>\n");
                string path_base = HttpContext.Current.Server.MapPath("./") + "btnet_base_notifications.css";
                string path_custom = HttpContext.Current.Server.MapPath("./") + "btnet_custom_notifications.css";

                if (System.IO.File.Exists(path_base))
                {
                    Response.WriteFile(path_base);
                }
                else
                {
                    Response.WriteFile(HttpContext.Current.Server.MapPath("./") + "btnet_base.css");
                }
                Response.Write("\n");

                if (System.IO.File.Exists(path_custom))
                {
                    Response.WriteFile(path_custom);
                }
                else
                {
                    Response.WriteFile(HttpContext.Current.Server.MapPath("./custom/") + "btnet_custom.css");
                }

                // underline links in the emails to make them more obvious
                Response.Write("\na {text-decoration: underline; }");
                Response.Write("\na:visited {text-decoration: underline; }");
                Response.Write("\na:hover {text-decoration: underline; }");
                Response.Write("\n</style>\n");
            }

			Response.Write ("<body style='background:white'>");
			Response.Write ("<b>"
				+ btnet.Util.capitalize_first_letter(btnet.Util.get_setting("SingularBugLabel","bug"))
				+ " ID:&nbsp;<a href="
				+ btnet.Util.get_setting("AbsoluteUrlPrefix","http://127.0.0.1/")
				+ "edit_bug.aspx?id="
				+ string_bugid
				+ ">"
				+ string_bugid
				+ "</a><br>");

			Response.Write ("Short desc:&nbsp;<a href="
				+ btnet.Util.get_setting("AbsoluteUrlPrefix","http://127.0.0.1/")
				+ "edit_bug.aspx?id="
				+ string_bugid
				+ ">"
				+ HttpUtility.HtmlEncode((string)dr["short_desc"])
				+ "</a></b><p>");

			// start of the table with the bug fields
			Response.Write ("\n<table border=1 cellpadding=3 cellspacing=0>");
            Response.Write("\n<tr><td>Last changed by<td>"
				+ btnet.Util.format_username((string)dr["last_updated_user"],(string)dr["last_updated_fullname"])
				+ "&nbsp;");
            Response.Write("\n<tr><td>Reported By<td>"
				+ btnet.Util.format_username((string)dr["reporter"],(string)dr["reporter_fullname"])
				+ "&nbsp;");
            Response.Write("\n<tr><td>Reported On<td>" + btnet.Util.format_db_date(dr["reported_date"]) + "&nbsp;");
            Response.Write("\n<tr><td>Project<td>" + dr["current_project"] + "&nbsp;");
            Response.Write("\n<tr><td>Organization<td>" + dr["og_name"] + "&nbsp;");
            Response.Write("\n<tr><td>Category<td>" + dr["category_name"] + "&nbsp;");
            Response.Write("\n<tr><td>Priority<td>" + dr["priority_name"] + "&nbsp;");
            Response.Write("\n<tr><td>Assigned<td>"
				+ btnet.Util.format_username((string)dr["assigned_to_username"],(string)dr["assigned_to_fullname"])
				+ "&nbsp;");
            Response.Write("\n<tr><td>Status<td>" + dr["status_name"] + "&nbsp;");

			if (btnet.Util.get_setting("ShowUserDefinedBugAttribute","1") == "1")
			{
                Response.Write("\n<tr><td>"
					+ btnet.Util.get_setting("UserDefinedBugAttributeName","YOUR ATTRIBUTE")
					+ "<td>"
					+ dr["udf_name"] + "&nbsp;");
			}

			// Get custom column info  (There's an inefficiency here - we just did this
			// same call in get_bug_datarow...)

			DbUtil dbutil = new DbUtil();
			DataSet ds_custom_cols = btnet.Util.get_custom_columns(dbutil);


			// Show custom columns

			foreach (DataRow drcc in ds_custom_cols.Tables[0].Rows)
			{
                Response.Write("\n<tr><td>");
				Response.Write (drcc["name"]);
				Response.Write ("<td>");

				if ((string)drcc["datatype"] == "datetime")
				{
					object dt = dr[(string)drcc["name"]];

					Response.Write (btnet.Util.format_db_date(dt));
				}
				else
				{
					string s = "";

					if ((string)drcc["dropdown type"] == "users")
					{
						object obj = dr[(string)drcc["name"]];
						if (obj.GetType().ToString() != "System.DBNull")
						{
							int userid = Convert.ToInt32(obj);
							if (userid != 0)
							{
								string sql_get_username = "select us_username from users where us_id = $1";
								s = (string) dbutil.execute_scalar(sql_get_username.Replace("$1", Convert.ToString(userid)));
							}
						}
					}
					else
					{
						s = Convert.ToString(dr[(string)drcc["name"]]);
					}

					s = HttpUtility.HtmlEncode(s);
					s = s.Replace("\n","<br>");
					s = s.Replace("  ","&nbsp; ");
					s = s.Replace("\t","&nbsp;&nbsp;&nbsp;&nbsp;");
					Response.Write (s);
				}
				Response.Write ("&nbsp;");
			}


			// create project custom dropdowns
			if ((int)dr["project"] != 0)
			{

				string sql = @"select
					isnull(pj_enable_custom_dropdown1,0) [pj_enable_custom_dropdown1],
					isnull(pj_enable_custom_dropdown2,0) [pj_enable_custom_dropdown2],
					isnull(pj_enable_custom_dropdown3,0) [pj_enable_custom_dropdown3],
					isnull(pj_custom_dropdown_label1,'') [pj_custom_dropdown_label1],
					isnull(pj_custom_dropdown_label2,'') [pj_custom_dropdown_label2],
					isnull(pj_custom_dropdown_label3,'') [pj_custom_dropdown_label3]
					from projects where pj_id = $pj";

				sql = sql.Replace("$pj", Convert.ToString((int)dr["project"]));

				DataRow project_dr = dbutil.get_datarow(sql);


				if (project_dr != null)
				{
					for (int i = 1; i < 4; i++)
					{
						if ((int)project_dr["pj_enable_custom_dropdown" + Convert.ToString(i)] == 1)
						{
                            Response.Write("\n<tr><td>");
							Response.Write (project_dr["pj_custom_dropdown_label" + Convert.ToString(i)]);
							Response.Write ("<td>");
							Response.Write (dr["bg_project_custom_dropdown_value"  + Convert.ToString(i)]);
							Response.Write ("&nbsp;");
						}
					}
				}
			}



			Response.Write("\n</table><p>"); // end of the table with the bug fields


			// don't write links, don't show images, do show update history
			write_posts (Response, bugid, 0, false, false, true,
				this_is_admin,
				false,
				this_external_user);

			Response.Write ("</body>");

		}


		///////////////////////////////////////////////////////////////////////
		public static void write_posts(
			HttpResponse Response,
			int bugid,
			int permission_level,
			bool write_links,
			bool images_inline,
			bool history_inline,
			bool this_is_admin,
			bool this_can_edit_and_delete_posts,
			bool this_external_user)
		{

			Response.Write ("\n<table id='posts_table' border=0 cellpadding=0 cellspacing=3>");
			DataSet ds_posts = btnet.Bug.get_bug_posts(bugid);

			int bp_id;
			int prev_bp_id = -1;

			foreach (DataRow dr in ds_posts.Tables[0].Rows)
			{

				if (this_external_user)
				{
					if ((int)dr["bp_hidden_from_external_users"] == 1)
					{
						continue; // don't show
					}
				}

				bp_id = (int) dr["bp_id"];


				if ((string)dr["bp_type"] == "update")
				{
					if (!history_inline)
					{
						continue;
					}
				}

				if (bp_id == prev_bp_id)
				{
					// show another attachment
					write_email_attachment(Response, bugid, dr, write_links, images_inline);
				}
				else
				{
					// show the comment and maybe an attachment
					if (prev_bp_id != -1) {
						Response.Write ("\n</table>"); // end the previous table
					}

					write_post(Response, bugid, permission_level, dr, bp_id, write_links, images_inline,
						this_is_admin,
						this_can_edit_and_delete_posts,
						this_external_user);


					if (Convert.ToString(dr["ba_file"]) != "") // intentially "ba"
					{
						write_email_attachment(Response, bugid, dr, write_links, images_inline);
					}
					prev_bp_id = bp_id;
				}

			}

			if (prev_bp_id != -1) {
				Response.Write ("\n</table>"); // end the previous table
			}

			Response.Write ("\n</table>");
		}

		///////////////////////////////////////////////////////////////////////
		public static void write_post(
			HttpResponse Response,
			int bugid,
			int permission_level,
			DataRow dr,
			int post_id,
			bool write_links,
			bool images_inline,
			bool this_is_admin,
            bool this_can_edit_and_delete_posts,
            bool this_external_user)
		{
			string type = (string)dr["bp_type"];

			string string_post_id = Convert.ToString(post_id);
			string string_bug_id = Convert.ToString(bugid);

			Response.Write ("\n\n<tr><td class=cmt>\n<table width=100%>\n<tr><td align=left>");


			/*
				Format one of the following:

				changed by
				email sent to
				email received from
				file attached by
				comment posted by

			*/

			if (type == "update")
			{
				// posted by
				Response.Write ("<span class=pst>changed by ");
				Response.Write (format_email_username(
					write_links,
					bugid,
					(string) dr["us_email"],
					(string) dr["us_username"],
					(string) dr["us_fullname"]));
			}
			else if (type == "sent")
			{
				Response.Write ("<span class=pst>email <a name=" + Convert.ToString(post_id) +  "></a>" + Convert.ToString(post_id) + " sent to ");

				if (write_links)
				{
					Response.Write (format_email_to(
						bugid,
						HttpUtility.HtmlEncode((string)dr["bp_email_to"])));
				}
				else
				{
					Response.Write (HttpUtility.HtmlEncode((string)dr["bp_email_to"]));
				}

				Response.Write (" by ");

				Response.Write (format_email_username(
					write_links,
					bugid,
					(string) dr["us_email"],
					(string) dr["us_username"],
					(string) dr["us_fullname"]));
			}
			else if (type == "received" )
			{
				Response.Write ("<span class=pst>email <a name=" + Convert.ToString(post_id) +  "></a>" + Convert.ToString(post_id) + " received from ");
				if (write_links)
				{
					Response.Write (format_email_from(
						post_id,
						(string)dr["bp_email_from"]));
				}
				else
				{
					Response.Write ((string)dr["bp_email_from"]);
				}
			}
			else if (type == "file" )
			{
				if ((int) dr["bp_hidden_from_external_users"] == 1)
				{
					Response.Write("<div class=private>Internal Only!</div>");
				}
				Response.Write ("<span class=pst>file <a name=" + Convert.ToString(post_id) +  "></a>" + Convert.ToString(post_id) + " attached by ");
				Response.Write (format_email_username(
					write_links,
					bugid,
					(string) dr["us_email"],
					(string) dr["us_username"],
					(string) dr["us_fullname"]));
			}
			else if (type == "comment" )
			{
				if ((int) dr["bp_hidden_from_external_users"] == 1)
				{
					Response.Write("<div class=private>Internal Only!</div>");
				}
				Response.Write ("<span class=pst>comment <a name=" + Convert.ToString(post_id) +  "></a>" + Convert.ToString(post_id) + " posted by ");
				Response.Write (format_email_username(
					write_links,
					bugid,
					(string) dr["us_email"],
					(string) dr["us_username"],
					(string) dr["us_fullname"]));
			}
			else
			{
				System.Diagnostics.Debug.Assert(false);
			}


			// Format the date
			Response.Write (" on ");
			Response.Write (btnet.Util.format_db_date(dr["bp_date"]));
			Response.Write ("</span>");


			// Write the links

			if (write_links)
			{

				Response.Write ("<td align=right>&nbsp;");

				if (permission_level != Security.PERMISSION_READONLY)
				{
					if (type == "comment" || type == "sent" || type == "received")
					{
						Response.Write ("&nbsp;&nbsp;&nbsp;<a style='font-size: 8pt;'");
						Response.Write (" href=send_email.aspx?quote=1&bp_id=" + string_post_id + "&reply=forward");
						Response.Write (">forward</a>");
					}
				}

				// format links for responding to email
				if (type == "received" )
				{
					if (this_is_admin
					|| (this_can_edit_and_delete_posts
					&& permission_level == Security.PERMISSION_ALL))
					{
					// This doesn't just work.  Need to make changes in edit/delete pages.
					//	Response.Write ("&nbsp;&nbsp;&nbsp;<a style='font-size: 8pt;'");
					//	Response.Write (" href=edit_comment.aspx?id="
					//		+ string_post_id + "&bug_id=" + string_bug_id);
					//	Response.Write (">edit</a>");

					// This delete leaves debris around, but it's better than nothing
						Response.Write ("&nbsp;&nbsp;&nbsp;<a style='font-size: 8pt;'");
						Response.Write (" href=delete_comment.aspx?id="
							+ string_post_id + "&bug_id=" + string_bug_id);
						Response.Write (">delete</a>");

					}

					if (permission_level != Security.PERMISSION_READONLY)
					{
						Response.Write ("&nbsp;&nbsp;&nbsp;<a style='font-size: 8pt;'");
						Response.Write (" href=send_email.aspx?quote=1&bp_id=" + string_post_id);
						Response.Write (">reply</a>");

						Response.Write ("&nbsp;&nbsp;&nbsp;<a style='font-size: 8pt;'");
						Response.Write (" href=send_email.aspx?quote=1&bp_id=" + string_post_id + "&reply=all");
						Response.Write (">reply all</a>");
					}

				}
				else if (type == "file")
				{

					if (this_is_admin
					|| (this_can_edit_and_delete_posts
					&& permission_level == Security.PERMISSION_ALL))
					{
						Response.Write ("&nbsp;&nbsp;&nbsp;<a style='font-size: 8pt;'");
						Response.Write (" href=edit_attachment.aspx?id="
							+ string_post_id + "&bug_id=" + string_bug_id);
						Response.Write (">edit</a>");

						Response.Write ("&nbsp;&nbsp;&nbsp;<a style='font-size: 8pt;'");
						Response.Write (" href=delete_attachment.aspx?id="
							+ string_post_id + "&bug_id=" + string_bug_id);
						Response.Write (">delete</a>");

					}
				}
				else if (type == "comment")
				{
					if (this_is_admin
					|| (this_can_edit_and_delete_posts
					&& permission_level == Security.PERMISSION_ALL))
					{
						Response.Write ("&nbsp;&nbsp;&nbsp;<a style='font-size: 8pt;'");
						Response.Write (" href=edit_comment.aspx?id="
							+ string_post_id + "&bug_id=" + string_bug_id);
						Response.Write (">edit</a>");

						Response.Write ("&nbsp;&nbsp;&nbsp;<a style='font-size: 8pt;'");
						Response.Write (" href=delete_comment.aspx?id="
							+ string_post_id + "&bug_id=" + string_bug_id);
						Response.Write (">delete</a>");
					}
				}


				// custom bug link
				if (btnet.Util.get_setting("CustomPostLinkLabel","") != "")
				{

					string custom_post_link = "&nbsp;&nbsp;&nbsp;<a style='font-size: 8pt;' href="
						+ btnet.Util.get_setting("CustomPostLinkUrl","")
						+ "?postid="
						+ string_post_id
						+ ">"
						+ btnet.Util.get_setting("CustomPostLinkLabel","")
						+ "</a>";

					Response.Write (custom_post_link);

				}


			}

			Response.Write ("\n</table>\n<table border=0>\n<tr><td>");
			// the text itself
			string comment = (string) dr["bp_comment"];
			string comment_type = (string) dr["bp_content_type"];
			comment = format_comment(comment, comment_type);


			if (type == "file")
			{
				if (comment.Length > 0)
				{
					Response.Write (comment);
					Response.Write ("<p>");
				}

				Response.Write ("<span class=pst>");
				if (write_links)
				{
					Response.Write("<img src=attach.gif>");
				}
				Response.Write ("attachment:&nbsp;</span>");
				Response.Write (dr["bp_file"]);

				if (write_links)
				{
					Response.Write ("&nbsp;&nbsp;&nbsp;<a target=_blank style='font-size: 8pt;'");
					Response.Write (" href=view_attachment.aspx?download=0&id="
						+ string_post_id + "&bug_id=" + string_bug_id);
					Response.Write (">view</a>");

					Response.Write ("&nbsp;&nbsp;&nbsp;<a target=_blank style='font-size: 8pt;'");
					Response.Write (" href=view_attachment.aspx?download=1&id="
						+ string_post_id + "&bug_id=" + string_bug_id);
					Response.Write (">save</a>");
				}

				Response.Write ("<p><span class=pst>size: ");
				Response.Write (dr["bp_size"]);
				Response.Write ("&nbsp;&nbsp;&nbsp;content-type: ");
				Response.Write (dr["bp_content_type"]);
				Response.Write ("</span>");


			}
			else
			{
				Response.Write (comment);
			}


			// maybe show inline images
			if (type == "file")
			{
				if (images_inline)
				{
					string file = Convert.ToString(dr["bp_file"]);
					write_file_inline (Response, file, string_post_id, string_bug_id);
				}
			}

		}


		///////////////////////////////////////////////////////////////////////
		protected static void write_email_attachment(HttpResponse Response, int bugid, DataRow dr, bool write_links, bool images_inline)
		{

			string string_post_id = Convert.ToString(dr["ba_id"]); // intentially "ba"
			string string_bug_id = Convert.ToString(bugid);

			Response.Write ("\n<p><span class=pst>");
			if (write_links)
			{
				Response.Write("<img src=attach.gif>");
			}
			Response.Write("attachment:&nbsp;</span>");
			Response.Write (dr["ba_file"]); // intentially "ba"
			Response.Write ("&nbsp;&nbsp;&nbsp;&nbsp;");

			if (write_links)
			{
				Response.Write ("<a target=_blank href=view_attachment.aspx?download=0&id=");
				Response.Write (string_post_id);
				Response.Write ("&bug_id=");
				Response.Write (string_bug_id);
				Response.Write (">view</a>&nbsp;&nbsp;&nbsp;&nbsp;");

				Response.Write ("<a target=_blank href=view_attachment.aspx?download=1&id=");
				Response.Write (string_post_id);
				Response.Write ("&bug_id=");
				Response.Write (string_bug_id);
				Response.Write (">save</a>");
			}

			if (images_inline)
			{
				string file = Convert.ToString(dr["ba_file"]);  // intentially "ba"
				write_file_inline (Response, file, string_post_id, string_bug_id);

			}

			Response.Write ("<p><span class=pst>size: ");
			Response.Write (dr["ba_size"]);
			Response.Write ("&nbsp;&nbsp;&nbsp;content-type: ");
			Response.Write (dr["ba_content_type"]);
			Response.Write ("</span>");

		}


		///////////////////////////////////////////////////////////////////////
		protected static void write_file_inline (HttpResponse Response, string file, string string_post_id, string string_bug_id)
		{

			if (file.ToLower().EndsWith(".gif")
			|| file.ToLower().EndsWith(".jpg")
			|| file.ToLower().EndsWith(".jpeg")
			|| file.ToLower().EndsWith(".bmp")
			|| file.ToLower().EndsWith(".png"))
			{
				Response.Write ("<p>"
					+ "<a href=javascript:resize_image('im" + string_post_id + "',1.5)>" + "[+]</a>&nbsp;"
					+ "<a href=javascript:resize_image('im" + string_post_id + "',.6)>" + "[-]</a>"
					+ "<br><img id=im" + string_post_id
					+ " src=view_attachment.aspx?download=0&id="
					+ string_post_id + "&bug_id=" + string_bug_id
					+ ">");
			}
			else if (file.ToLower().EndsWith(".html")
			|| file.ToLower().EndsWith(".htm")
			|| file.ToLower().EndsWith(".ini")
			|| file.ToLower().EndsWith(".xml")
			|| file.ToLower().EndsWith(".txt"))
			{
				Response.Write ("<p>"
					+ "<a href=javascript:resize_iframe('if" + string_post_id + "',200)>" + "[+]</a>&nbsp;"
					+ "<a href=javascript:resize_iframe('if" + string_post_id + "',-200)>" + "[-]</a>"
					+ "<br><iframe id=if"
					+ string_post_id
					+ " width=780 height=200 src=view_attachment.aspx?download=0&id="
					+ string_post_id + "&bug_id=" + string_bug_id
					+ "></iframe>");
			}

		}

        ///////////////////////////////////////////////////////////////////////
        public static string format_email_username(
            bool write_links,
            int bugid,
            string email,
            string username,
            string fullname)
        {
            if (email != null && email != "" && write_links)
            {
                return "<a href="
                + Util.get_setting("AbsoluteUrlPrefix", "http://127.0.0.1/")
                + "send_email.aspx?bg_id=" + Convert.ToString(bugid)
                + "&to=" + email + ">"
                + btnet.Util.format_username(username, fullname)
                + "</a>";
            }
            else
            {
                return btnet.Util.format_username(username, fullname);
            }

        }

        ///////////////////////////////////////////////////////////////////////
        public static string format_email_to(int bugid, string email)
        {
            return "<a href="
            + Util.get_setting("AbsoluteUrlPrefix", "http://127.0.0.1/")
            + "send_email.aspx?bg_id=" + Convert.ToString(bugid)
            + "&to=" + HttpUtility.UrlEncode(HttpUtility.HtmlDecode(email)) + ">"
            + email
            + "</a>";
        }


        ///////////////////////////////////////////////////////////////////////
        public static string format_email_from(int comment_id, string from)
        {

            string display_part = "";
            string email_part = "";
            int pos = from.IndexOf("<"); // "

            if (pos > 0)
            {
                display_part = from.Substring(0, pos);
                email_part = from.Substring(pos + 1, (from.Length - pos) - 2);
            }
            else
            {
                email_part = from;
            }


            return display_part
                + "<a href="
                + Util.get_setting("AbsoluteUrlPrefix", "http://127.0.0.1/")
                + "send_email.aspx?bp_id="
                + Convert.ToString(comment_id)
                + ">"
                + email_part
                + "</a>";

        }

        ///////////////////////////////////////////////////////////////////////
        public static string format_comment(string s1, string t1)
        {
            string s2;
            string link_marker;

            if (t1 != "text/html")
            {
                s2 = HttpUtility.HtmlEncode(s1);

                // convert urls to links
                s2 = reHyperlinks.Replace(
                    s2,
                    new MatchEvaluator(convert_to_hyperlink));

                // convert email addresses to mailto links
                s2 = reEmail.Replace(
                    s2,
                    new MatchEvaluator(convert_to_email));

                s2 = s2.Replace("\n", "<br>");
                s2 = s2.Replace("  ", "&nbsp; ");
                s2 = s2.Replace("\t", "&nbsp;&nbsp;&nbsp;&nbsp;");

                // convert references to other bugs to links
                link_marker = Util.get_setting("BugLinkMarker", "bugid#");
                Regex reLinkMarker = new Regex(link_marker + "[0-9]+");
                s2 = reLinkMarker.Replace(
                    s2,
                    new MatchEvaluator(convert_bug_link));

                // wrap it up with the proper style
                return "<span class=cmt_text>" + s2 + "</span>";
            }
            else
            {
                s2 = s1;

                link_marker = Util.get_setting("BugLinkMarker", "bugid#");
                Regex reLinkMarker = new Regex(link_marker + "[0-9]+");
                s2 = reLinkMarker.Replace(
                    s2,
                    new MatchEvaluator(convert_bug_link));

                return s2;
            }
        }

        ///////////////////////////////////////////////////////////////////////
        static string convert_to_email(Match m)
        {
            // Get the matched string.
            return String.Format("<a href='mailto:{0}'>{0}</a>", m.ToString());
        }

        ///////////////////////////////////////////////////////////////////////
        static string convert_bug_link(Match m)
        {

            string link_marker = Util.get_setting("BugLinkMarker", "bugid#");
            string just_number = m.ToString().Replace(link_marker, "");

            return "<a href="
                + btnet.Util.get_setting("AbsoluteUrlPrefix", "http://127.0.0.1/")
                + "edit_bug.aspx?id="
                + just_number
                + ">"
                + m.ToString()
                + "</a>";

        }

        ///////////////////////////////////////////////////////////////////////
        static string convert_to_hyperlink(Match m)
        {
            return String.Format("<a target=_blank href='{0}'>{0}</a>", m.ToString());
        }


	} // end PrintBug


} // end namespace