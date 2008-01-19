/*
Copyright 2002 Corey Trager
Distributed under the terms of the GNU General Public License
*/

using System;
using System.Data;
using System.Data.SqlClient;
using System.Data.OleDb;
using System.Collections;
using System.Collections.Specialized;
using System.Configuration;
using System.IO;
using System.Text;
using System.Text.RegularExpressions;
using System.Web;
using System.Web.Caching;
using System.Web.SessionState;
using System.Web.Security;
using System.Web.UI;
using System.Web.UI.WebControls;
using System.Web.UI.HtmlControls;

namespace btnet
{

	public class Security {

		public const int MUST_BE_ADMIN = 1;
		public const int ANY_USER_OK = 2;
		public const int ANY_USER_OK_EXCEPT_GUEST = 3;
		public const int MUST_BE_ADMIN_OR_PROJECT_ADMIN = 4;

		public int this_usid = 0;
		public string this_username = "";
		public string this_fullname = "";
		public string this_email = "";
		public bool this_is_admin = false;
		public bool this_is_project_admin = false;
		public bool this_is_guest = false;
		public bool this_adds_not_allowed = false;
		public string auth_method = "";
		public int this_bugs_per_page;
		public int this_enable_popups;
		public bool this_use_fckeditor = false;

        public bool this_external_user = false;
        public bool this_can_edit_sql = false;
        public bool this_can_delete_bug = false;

        public bool this_can_edit_and_delete_posts = false;
        public bool this_can_merge_bugs = false;
        public bool this_can_mass_edit_bugs = false;

        public bool this_can_use_reports = false;
        public bool this_can_edit_reports = false;
        public bool this_can_be_assigned_to = true;

		public const int PERMISSION_NONE = 0;
		public const int PERMISSION_READONLY = 1;
		public const int PERMISSION_REPORTER = 3;
		public const int PERMISSION_ALL = 2;

        public int this_other_orgs_permission_level = PERMISSION_ALL;
        public int this_org = 0;
        public int this_forced_project = 0;

        public int this_assigned_to_field_permission_level = PERMISSION_ALL;
        public int this_status_field_permission_level = PERMISSION_ALL;
        public int this_category_field_permission_level = PERMISSION_ALL;
		public int this_priority_field_permission_level = PERMISSION_ALL;
		public int this_project_field_permission_level = PERMISSION_ALL;
		public int this_org_field_permission_level = PERMISSION_ALL;
		public int this_udf_field_permission_level = PERMISSION_ALL;

		///////////////////////////////////////////////////////////////////////
		public void check_security(DbUtil dbutil, HttpContext asp_net_context, int level)
		{
			Util.set_context(asp_net_context);
			HttpRequest Request = asp_net_context.Request;
			HttpResponse Response = asp_net_context.Response;


			// for limiting pages views, for example when app is hosted publically as a demo

			int page_view_limit = Convert.ToInt32(Util.get_setting("PageViewLimit","0"));

			if (page_view_limit > 0)
			{
				int pages_viewed = 0;
				object obj = asp_net_context.Application[Request.ServerVariables["REMOTE_ADDR"]];
				if (obj != null)
				{
					pages_viewed = (int) obj;
				}

				pages_viewed++;

				if (pages_viewed > page_view_limit)
				{
					Response.Write("Page view limit exceeded");
					Response.End();
				}
				else
				{
					asp_net_context.Application[Request.ServerVariables["REMOTE_ADDR"]] = pages_viewed;
				}
			}


			HttpCookie cookie = Request.Cookies["se_id"];

			// This logic allows somebody to put a link in an email, like
			// edit_bug.aspx?id=66
			// The user would click on the link, go to the logon page (default.aspx),
			// and then after logging in continue on to edit_bug.aspx?id=66
			string original_url = Request.ServerVariables["URL"].ToString().ToLower();
			string original_querystring = Request.ServerVariables["QUERY_STRING"].ToString().ToLower();
			string target = "default.aspx?url=" + original_url + "&qs=" + HttpUtility.UrlEncode(original_querystring);

			if (cookie == null)
			{
				Util.write_to_log ("se_id cookie is null, so redirecting");
				Util.write_to_log ("Trouble logging in?  Your browser might be failing to send back its cookie.");
				Util.write_to_log ("See Help forum at http://sourceforge.net/forum/forum.php?forum_id=226938");
				Response.Redirect(target);
			}

			Util.write_to_log ("session=" + cookie.Value);

			// guard against "Sql Injection" exploit
			string se_id = cookie.Value.Replace("'", "''");

			// check for existing session for active user
			string sql = @"/* check session */
				declare @project_admin int
				select @project_admin = count(1)
					from sessions
					inner join project_user_xref on pu_user = se_user
					and pu_admin = 1
					where se_id = '$se';

				select us_id, us_admin,
				us_username, us_firstname, us_lastname,
				isnull(us_email,'') us_email,
				isnull(us_bugs_per_page,10) us_bugs_per_page,
				isnull(us_forced_project,0) us_forced_project,
				us_use_fckeditor,
				us_enable_bug_list_popups,
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
				og_category_field_permission_level,
				og_priority_field_permission_level,
				og_assigned_to_field_permission_level,
				og_status_field_permission_level,
				og_project_field_permission_level,
				og_org_field_permission_level,
				og_udf_field_permission_level,
				og_id,
				isnull(us_forced_project, 0 ) us_forced_project,
				isnull(pu_permission_level, $dpl) pu_permission_level,
				@project_admin [project_admin]
				from sessions
				inner join users on se_user = us_id
				inner join orgs on us_org = og_id
				left outer join project_user_xref
					on pu_project = us_forced_project
					and pu_user = us_id
				where se_id = '$se'
				and us_active = 1";


			sql = sql.Replace("$se", se_id);
			sql = sql.Replace("$dpl", Util.get_setting("DefaultPermissionLevel","2"));

			DataRow dr = dbutil.get_datarow(sql);

			// no previously established session
			if (dr == null)
			{
				Response.Redirect(target);
			}

			asp_net_context.Session["session_cookie"] = cookie.Value;

			this_usid = Convert.ToInt32(dr["us_id"]);
			this_username = (string) dr["us_username"];
			this_email = (string) dr["us_email"];

            this_bugs_per_page = Convert.ToInt32(dr["us_bugs_per_page"]);
			this_use_fckeditor = Convert.ToBoolean(dr["us_use_fckeditor"]);
			this_enable_popups = Convert.ToInt32(dr["us_enable_bug_list_popups"]);

            this_external_user = Convert.ToBoolean(dr["og_external_user"]);
            this_can_edit_sql = Convert.ToBoolean(dr["og_can_edit_sql"]);
            this_can_delete_bug = Convert.ToBoolean(dr["og_can_delete_bug"]);
            this_can_edit_and_delete_posts = Convert.ToBoolean(dr["og_can_edit_and_delete_posts"]);
            this_can_merge_bugs = Convert.ToBoolean(dr["og_can_merge_bugs"]);
            this_can_mass_edit_bugs = Convert.ToBoolean(dr["og_can_mass_edit_bugs"]);
            this_can_use_reports = Convert.ToBoolean(dr["og_can_use_reports"]);
            this_can_edit_reports = Convert.ToBoolean(dr["og_can_edit_reports"]);
            this_can_be_assigned_to = Convert.ToBoolean(dr["og_can_be_assigned_to"]);
            this_other_orgs_permission_level = (int) dr["og_other_orgs_permission_level"];
            this_org = (int) dr["og_id"];
            this_forced_project = (int) dr["us_forced_project"];

            this_category_field_permission_level = (int) dr["og_category_field_permission_level"];
            this_priority_field_permission_level = (int) dr["og_priority_field_permission_level"];
            this_assigned_to_field_permission_level = (int) dr["og_assigned_to_field_permission_level"];
            this_status_field_permission_level = (int) dr["og_status_field_permission_level"];
            this_project_field_permission_level = (int) dr["og_project_field_permission_level"];
            this_org_field_permission_level = (int) dr["og_org_field_permission_level"];
            this_udf_field_permission_level = (int) dr["og_udf_field_permission_level"];


			if (((string)dr["us_firstname"]).Trim().Length == 0)
			{
				this_fullname = (string) dr["us_lastname"];
			}
			else
			{
			this_fullname = (string) dr["us_lastname"] + ", " + (string) dr["us_firstname"];
			}

			Util.write_to_log ("userid=" + Convert.ToString(this_usid));
			Util.write_to_log ("username=" + this_username);

			if ((int)dr["us_admin"] == 1)
			{
				this_is_admin = true;
			}
			else
			{
				if ((int) dr["project_admin"] > 0)
				{
					this_is_project_admin = true;
				}
				else
				{
					if (this_username.ToLower() == "guest")
					{
						this_is_guest = true;
					}
				}
			}


			// if user is forced to a specific project, and doesn't have
			// at least reporter permission on that project, than user
			// can't add bugs
			if ((int)dr["us_forced_project"] != 0)
			{
				if ((int)dr["pu_permission_level"] == PERMISSION_READONLY
				||  (int)dr["pu_permission_level"] == PERMISSION_NONE)
				{
					this_adds_not_allowed = true;
				}
			}


			if (level == MUST_BE_ADMIN && !this_is_admin)
			{
				Response.Redirect("default.aspx");
			}
			else if (level == ANY_USER_OK_EXCEPT_GUEST && this_is_guest)
			{
				Response.Redirect("default.aspx");
			}
			else if (level == MUST_BE_ADMIN_OR_PROJECT_ADMIN && !this_is_admin && !this_is_project_admin)
			{
				Response.Redirect("default.aspx");
			}

			if (Util.get_setting("WindowsAuthentication","0") == "1")
			{
				auth_method = "windows";
			}
			else
			{
				auth_method = "plain";
			}
		}

		///////////////////////////////////////////////////////////////////////
		public static void write_menu_item(HttpResponse Response,
			string this_link, string menu_item, string href)
		{
			Response.Write ("<td valign=middle align=left>");
			if (this_link == menu_item)
			{
				Response.Write ("<a href=" + href + "><span class=selected_menu_item>" + menu_item + "</span></a>");	}
			else
			{
				if (menu_item == "about")
				{
					Response.Write ("<a target=_blank href=" + href + "><span class=menu_item>" + menu_item + "</span></a>");
				}
				else
				{
					Response.Write ("<a href=" + href + "><span class=menu_item>" + menu_item + "</span></a>");
				}
			}
			Response.Write ("</td>");
		}



		///////////////////////////////////////////////////////////////////////
		public void write_menu(HttpResponse Response, string this_link)
		{

			// topmost visible HTML
			string custom_header = (string) Util.context.Application["custom_header"];
			Response.Write(custom_header);

			Response.Write("<table border=0 width=100% cellpadding=0 cellspacing=0 class=menubar><tr>");

			// logo
			string logo = (string) Util.context.Application["custom_logo"];
			Response.Write(logo);

			Response.Write("<td width=20>&nbsp;</td>");
			write_menu_item(Response, this_link, Util.get_setting("PluralBugLabel","bugs"), "bugs.aspx");
			write_menu_item(Response, this_link, "search", "search.aspx");

			if (!this_is_guest)
			{
				write_menu_item(Response, this_link, "queries", "queries.aspx");
			}

			if (this_is_admin)
			{
				write_menu_item(Response, this_link, "admin", "admin.aspx");
			}
			else if (this_is_project_admin)
			{
				write_menu_item(Response, this_link, "users", "users.aspx");
			}

			if (this_is_admin || this_can_use_reports || this_can_edit_reports)
			{
				write_menu_item(Response, this_link, "reports", "reports.aspx");
			}


			// for guest account, suppress display of "edit_self
			if (!this_is_guest)
			{
				write_menu_item(Response, this_link, "settings", "edit_self.aspx");
			}

			if (auth_method == "plain")
			{
					write_menu_item(Response, this_link, "logoff", "logoff.aspx");
			}

			if (Util.get_setting("CustomMenuLinkLabel","") != "")
			{
				write_menu_item(Response, this_link,
					Util.get_setting("CustomMenuLinkLabel",""),
					Util.get_setting("CustomMenuLinkUrl",""));
			}

			write_menu_item(Response, this_link, "about", "about.html");

			// go to
			Response.Write("<td nowrap valign=middle>");
			Response.Write("<form style='margin: 0px; padding: 0px;' action=edit_bug.aspx method=get>");
			Response.Write("<font size=1>id:&nbsp;</font>");
			Response.Write("<input style='font-size: 8pt;' size=4 type=text name=id accesskey=i>");
			Response.Write("<input class=btn style='font-size: 8pt;' type=submit value='go to ");
			Response.Write(Util.get_setting("SingularBugLabel","bug"));
			Response.Write ("'>");
			Response.Write("</form>");
			Response.Write("</td>");

			Response.Write ("<td nowrap valign=middle>");
			Response.Write ("<span class=smallnote>logged in as:<br>");
			Response.Write (this_username);
			Response.Write ("</span></td>");

			Response.Write ("<td nowrap valign=middle>");
			Response.Write ("<a target=_blank href=http://ifdefined.com/README.html>[?]</a></td>");

			Response.Write("</tr></table><br>");

		}

	} // end Security


	///////////////////////////////////////////////////////////////////////
	///////////////////////////////////////////////////////////////////////
	// Util
	///////////////////////////////////////////////////////////////////////
	///////////////////////////////////////////////////////////////////////
	public class Util {

		public static HttpContext context = null;
		private static HttpRequest Request = null;
		//private static HttpResponse Response = null;
		//private static HttpServerUtility Server = null;

		static object dummy = new object();

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

		static Regex reCommas = new Regex(",");
		static Regex rePipes = new Regex("\\|");



		///////////////////////////////////////////////////////////////////////
		public static void set_context(HttpContext asp_net_context)
		{
			context = asp_net_context;
			Request = context.Request;
			//Response = context.Response;
			//Server = context.Server;

			Util.write_to_log ("url=" + Request.Url.PathAndQuery);

		}

		///////////////////////////////////////////////////////////////////////
		public static string get_form_name() {
			if (Environment.Version.ToString().Substring(0,1) == "1")
			{
				return "_ctl0";
			}
			else
			{
				return "ctl00";
			}
		}

		///////////////////////////////////////////////////////////////////////
		public static string get_log_file_path() {

			// determine log file name
			string log_file_folder = Util.get_log_folder();

			DateTime now = DateTime.Now;
			string now_string =
				(now.Year).ToString()
				+ "_" +
				(now.Month).ToString("0#")
				+ "_" +
				(now.Day).ToString("0#");

			string path = log_file_folder
				+ "\\"
				+ "btnet_log_"
				+ now_string
				+ ".txt";

			return path;

		}

		///////////////////////////////////////////////////////////////////////
		public static void write_to_log(string s)
		{

			if (Util.get_setting("LogEnabled","1") == "0")
			{
				return;
			}

			string path = get_log_file_path();

			lock(dummy)
			{
				System.IO.StreamWriter w = System.IO.File.AppendText(path);

				// write to it


				string url = "";
				if (Util.Request != null)
				{
					url = Util.Request.Url.ToString();
				}

				w.WriteLine(DateTime.Now.ToString("yyy-MM-dd HH:mm:ss")
					+ " "
					+ url
					+ " "
					+ s);

				w.Close();
			}
		}


		///////////////////////////////////////////////////////////////////////
		public static void do_not_cache(HttpResponse Response)
		{
			Response.CacheControl = "no-cache";
			Response.AddHeader ("Pragma", "no-cache");
			Response.Expires = -1;
		}

		///////////////////////////////////////////////////////////////////////
		public static string get_setting(string name, string default_value)
		{

			NameValueCollection name_values
                = (NameValueCollection)System.Configuration.ConfigurationManager.GetSection("btnetSettings");
			if (name_values[name] == null || name_values[name] == "")
			{
				return default_value;
			}
			else
			{
				return name_values[name];
			}
		}


		///////////////////////////////////////////////////////////////////////
		public static bool is_int(string maybe_int)
		{
			try
			{
				int i = Int32.Parse(maybe_int);
				return true;
			}
			catch (Exception)
			{
				return false;
			}
		}

		///////////////////////////////////////////////////////////////////////
		public static bool is_datetime(string maybe_datetime)
		{
			DateTime d;

			try
			{
				d = DateTime.Parse(maybe_datetime,get_culture_info());
				return true;
			}
			catch (Exception)
			{
				return false;
			}
		}

		///////////////////////////////////////////////////////////////////////
		public static string bool_to_string(bool b)
		{
			return (b ? "1" : "0");
		}


		///////////////////////////////////////////////////////////////////////
        public static string strip_html(string html) {
            return HttpUtility.HtmlDecode(Regex.Replace(html, @"<(.|\n)*?>", string.Empty));
        }


		///////////////////////////////////////////////////////////////////////
		public static System.Globalization.CultureInfo get_culture_info()
		{
			// Create a basic culture object to provide also all input parsing
			return new System.Globalization.CultureInfo(get_setting("CultureName",System.Threading.Thread.CurrentThread.CurrentCulture.Name));
		}

		///////////////////////////////////////////////////////////////////////
		public static string format_db_date(object date)
		{


			if (date.GetType().ToString() == "System.DBNull")
			{
				return "";
			}
			// not sure when this case happens, but it's a workaround for a bug
			// somebody reported, 1257368
			else if (date.GetType().ToString() == "System.String")
			{
				return date.ToString();
			}

			return ((DateTime)date).ToString(get_setting("DateTimeFormat","g"),get_culture_info());

		}

		//modified by CJU on jan 9 2008
		///////////////////////////////////////////////////////////////////////
		public static string format_db_value( Decimal val ) {

			return val.ToString( get_culture_info( ) );

		}

		///////////////////////////////////////////////////////////////////////
		public static string format_db_value( DateTime val ) {

			return format_db_date( val );

		}

		///////////////////////////////////////////////////////////////////////
		public static string format_db_value( object val ) {

			if( val is Decimal )
				return format_db_value( (Decimal)val );
			if( val is DateTime )
				return format_db_value( (DateTime)val );

			return HttpUtility.HtmlEncode( Convert.ToString( val ) );

		}
		//end modified by CJU on jan 9 2008

		///////////////////////////////////////////////////////////////////////
		public static string format_local_date_into_db_format(string date)
		{


			// seems to already be in the right format
			DateTime d;
			try
			{
				d = DateTime.Parse(date,get_culture_info());
			}
			catch (FormatException)
			{
				// Can not translate this
				return "";
			}
			// Note that yyyyMMdd hh:mm:ss is a universal SQL dateformat for strings.
			return d.ToString(get_setting("SQLServerDateFormat","yyyyMMdd hh:mm:ss"));

		}


		///////////////////////////////////////////////////////////////////////
		public static string format_local_decimal_into_db_format( string val )
		{
			decimal x = decimal.Parse(val, get_culture_info());

			return x.ToString( System.Globalization.CultureInfo.InvariantCulture );
		}

		///////////////////////////////////////////////////////////////////////
		static string convert_to_hyperlink(Match m)
		{
			return String.Format("<a target=_blank href='{0}'>{0}</a>", m.ToString());
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

			string link_marker = Util.get_setting("BugLinkMarker","bugid#");
			string just_number = m.ToString().Replace(link_marker,"");

			return "<a href="
				+ get_setting("AbsoluteUrlPrefix","http://127.0.0.1/")
				+ "edit_bug.aspx?id="
				+ just_number
				+ ">"
				+ m.ToString()
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
					new MatchEvaluator(Util.convert_to_hyperlink));

				// convert email addresses to mailto links
				s2 = reEmail.Replace(
					s2,
					new MatchEvaluator(Util.convert_to_email));

				s2 = s2.Replace("\n","<br>");
				s2 = s2.Replace("  ","&nbsp; ");
				s2 = s2.Replace("\t","&nbsp;&nbsp;&nbsp;&nbsp;");

				// convert references to other bugs to links
					link_marker = Util.get_setting("BugLinkMarker","bugid#");
				Regex reLinkMarker = new Regex(link_marker + "[0-9]+");
				s2 = reLinkMarker.Replace(
					s2,
					new MatchEvaluator(Util.convert_bug_link));

				// wrap it up with the proper style
				return "<span class=cmt_text>" + s2 + "</span>";
			}
			else
			{
				s2 = s1;

				link_marker = Util.get_setting("BugLinkMarker","bugid#");
				Regex reLinkMarker = new Regex(link_marker + "[0-9]+");
				s2 = reLinkMarker.Replace(
					s2,
					new MatchEvaluator(Util.convert_bug_link));

				return s2;
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
			if (email != null && email != ""  && write_links)
			{
				return "<a href="
				+ Util.get_setting("AbsoluteUrlPrefix","http://127.0.0.1/")
				+ "send_email.aspx?bg_id=" + Convert.ToString(bugid)
				+ "&to=" + email + ">"
				+ format_username(username, fullname)
				+ "</a>";
			}
			else
			{
				return format_username(username, fullname);
			}

		}


		///////////////////////////////////////////////////////////////////////
		public static string format_email_to(int bugid, string email)
		{
			return "<a href="
			+ Util.get_setting("AbsoluteUrlPrefix","http://127.0.0.1/")
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
				display_part = from.Substring(0,pos);
				email_part = from.Substring(pos + 1,(from.Length -  pos) - 2);
			}
			else
			{
				email_part = from;
			}


			return display_part
				+ "<a href="
				+ Util.get_setting("AbsoluteUrlPrefix","http://127.0.0.1/")
				+ "send_email.aspx?bp_id="
				+ Convert.ToString(comment_id)
				+ ">"
				+ email_part
				+ "</a>";

		}


		///////////////////////////////////////////////////////////////////////
		public static string alter_sql_per_project_permissions(string sql, Security security)
		{

			string project_permissions_sql;

			string dpl = Util.get_setting("DefaultPermissionLevel","2");

			if (dpl == "0")
			{
				project_permissions_sql = @" (bg_project in (
					select pu_project
					from project_user_xref
					where pu_user = $user
					and pu_permission_level > 0)) ";
			}
			else
			{
				project_permissions_sql = @" (bg_project not in (
					select pu_project
					from project_user_xref
					where pu_user = $user
					and pu_permission_level = 0)) ";
			}

			if (security.this_other_orgs_permission_level == 0)
			{
				project_permissions_sql += @"
					and bg_org = $this_org ";

			}

			project_permissions_sql
				= project_permissions_sql.Replace("$this_org",Convert.ToString(security.this_org));

			project_permissions_sql
				= project_permissions_sql.Replace("$user",Convert.ToString(security.this_usid));


			// figure out where to alter sql for project permissions

			string bug_sql;

			int where_pos = sql.IndexOf("WhErE"); // first look for a "special" where, case sensitive, in case there are multiple where's to choose from
			if (where_pos == -1) where_pos = sql.ToUpper().IndexOf("WHERE");
			int	order_pos = sql.ToUpper().LastIndexOf("ORDER BY");
			if (order_pos < where_pos) order_pos = -1; // ignore an order by that occurs in a subquery, for example
			Util.write_to_log(Convert.ToString(sql.Length) + " " + Convert.ToString(where_pos) + " " + Convert.ToString(order_pos));

			if (where_pos != -1 && order_pos != -1)
			{
				// both WHERE and ORDER BY clauses
				bug_sql = sql.Substring(0,where_pos + 5)
					+ " /* altered - both  */ ( "
					+ sql.Substring(where_pos + 5, order_pos-(where_pos+5))
					+ " ) AND ( "
					+ project_permissions_sql
					+ " ) "
					+ sql.Substring(order_pos);
			}
			else if (order_pos == -1 && where_pos == -1)
			{
				// Neither
				bug_sql = sql + " /* altered - neither */ WHERE " + project_permissions_sql;
			}
			else if (order_pos == -1)
			{
				// WHERE, without order
				bug_sql = sql.Substring(0,where_pos + 5)
					+ " /* altered - just where */ ( "
					+ sql.Substring(where_pos + 5)
					+ " ) AND ( "
					+  project_permissions_sql + " )";
			}
			else
			{
				// ORDER BY, without WHERE
				bug_sql = sql.Substring(0,order_pos)
					+ " /* altered - just order by  */ WHERE "
					+ project_permissions_sql
					+ sql.Substring(order_pos);
			}

			return bug_sql;

		}




		///////////////////////////////////////////////////////////////////////
		public static string encrypt_string_using_MD5(string s)
		{

			byte[] byte_array = System.Text.Encoding.Default.GetBytes(s);

			System.Security.Cryptography.HashAlgorithm alg =
				System.Security.Cryptography.HashAlgorithm.Create("MD5");

			byte[] byte_array2 = alg.ComputeHash(byte_array);

			System.Text.StringBuilder sb
				= new System.Text.StringBuilder(byte_array2.Length);

			foreach(byte b in byte_array2)
			{
				sb.AppendFormat("{0:X2}", b);
			}

			return sb.ToString();
		}


		///////////////////////////////////////////////////////////////////////
		public static string capitalize_first_letter(string s)
		{
			if (s.Length > 0 && Util.get_setting("NoCapitalization","0") == "0")
			{
				return s.Substring(0,1).ToUpper() + s.Substring(1,s.Length-1);
			}
			return s;

		}


		///////////////////////////////////////////////////////////////////////
		public static string sanitize_integer(string s)
		{
			int n;
			string s2;
			try
			{
				n = Convert.ToInt32(s);
				s2 = Convert.ToString(n);
			}
			catch
			{
				throw (new Exception("Expected integer.  Possible SQL injection attempt?"));

			}

			return s;
		}


		///////////////////////////////////////////////////////////////////////
		public static bool is_numeric_datatype(string datatype)
		{

			if (datatype == "System.Int32"
			|| datatype == "System.Decimal"
			|| datatype == "System.Double"
			|| datatype == "System.Single"
			|| datatype == "System.UInt32"
			|| datatype == "System.Int64"
			|| datatype == "System.UInt64"
			|| datatype == "System.Int16"
			|| datatype == "System.UInt16")
			{
				return true;
			}
			else
			{
				return false;
			}


		}

		///////////////////////////////////////////////////////////////////////
		public static string format_username(string username, string fullname)
		{

			if (Util.get_setting("UseFullNames","0") == "0")
			{
				return username;
			}
			else
			{
				return fullname;
			}
		}


		///////////////////////////////////////////////////////////////////////
		protected static string get_absolute_or_relative_folder(string folder)
		{

			if (folder.IndexOf(":") == 1
			|| folder.StartsWith("\\\\"))
			{
				// leave as is
				return folder;
			}
			else
			{
				return context.Server.MapPath("./") + folder;
			}

		}

		///////////////////////////////////////////////////////////////////////
		public static string get_upload_folder()
		{
            String folder = Util.get_setting("UploadFolder", "");
            if (folder == "")
                return null;

            folder = get_absolute_or_relative_folder(folder);
			if (!System.IO.Directory.Exists(folder))
			{
				throw (new Exception("UploadFolder specified in Web.config, \""
				+ folder
				+ "\", not found.  Edit Web.config."));
			}


			return folder;

		}

		///////////////////////////////////////////////////////////////////////
		public static string get_log_folder()
		{

			string folder = get_absolute_or_relative_folder(
				Util.get_setting("LogFileFolder","c:\\"));

			if (!System.IO.Directory.Exists(folder))
			{
				throw (new Exception("LogFileFolder specified in Web.config, \""
				+ folder
				+ "\", not found.  Edit Web.config."));
			}


			return folder;

		}

		///////////////////////////////////////////////////////////////////////
		public static string[] split_string_using_commas(string s)
		{
			return reCommas.Split(s);
		}


		///////////////////////////////////////////////////////////////////////
		public static string[] split_string_using_pipes(string s)
		{
			return rePipes.Split(s);
		}

		///////////////////////////////////////////////////////////////////////
		public static DataTable get_related_users(Security security, DbUtil dbutil)
		{
			string sql = "";

			if (Util.get_setting("DefaultPermissionLevel","2") == "0")
			{
				// only show users who have explicit permission
				// for projects that this user has permissions for

				sql = @"
/* get related users 1 */

select us_id,
case when $fullnames then
	case rtrim(us_firstname)
		when null then isnull(us_lastname, '')
		when '' then isnull(us_lastname, '')
		else isnull(us_lastname + ', ' + us_firstname,'')
	end
else us_username end us_username,
us_org,
og_external_user
into #temp
from users
inner join orgs on us_org = og_id
where us_id in
	(select pu1.pu_user from project_user_xref pu1
	where pu1.pu_project in
		(select pu2.pu_project from project_user_xref pu2
		where pu2.pu_user = $this_usid
		and pu2.pu_permission_level <> 0
		)
	and pu1.pu_permission_level <> 0
	)

if $og_external_user = 1 -- external
and $og_other_orgs_permission_level = 0 -- other orgs
	delete from #temp where us_org <> $this_org and us_id <> $this_usid

select us_id, us_username from #temp order by us_username
drop table #temp";



			}
			else
			{
				// show users UNLESS they have been explicitly excluded
				// from all the projects the viewer is able to view

				// the cartesian join in the first select is intentional

				sql=@"
/* get related users 2 */
select  pj_id, us_id,
case when $fullnames then
	case rtrim(us_firstname)
		when null then isnull(us_lastname, '')
		when '' then isnull(us_lastname, '')
		else isnull(us_lastname + ', ' + us_firstname,'')
	end
else us_username end us_username
into #temp
from projects, users
where pj_id not in
(
	select pu_project from project_user_xref
	where pu_permission_level = 0 and pu_user = $this_usid
)

if $og_external_user = 1 -- external
and $og_other_orgs_permission_level = 0 -- other orgs
begin
	select a.*
	into #temp2
	from #temp a
	inner join users b on a.us_id = b.us_id
	inner join orgs on b.us_id = og_id
	where og_external_user = 0 or b.us_org = $this_org

	select * from #temp order by us_username
	drop table #temp2
end
else
begin

	select distinct us_id, us_username
		from #temp
		left outer join project_user_xref on pj_id = pu_project
		and us_id = pu_user
		where isnull(pu_permission_level,2) <> 0
		order by us_username

end

drop table #temp";

			}



			if (Util.get_setting("UseFullNames","0") == "0")
			{
				// false condition
				sql = sql.Replace("$fullnames","0 = 1");
			}
			else
			{
				// true condition
				sql = sql.Replace("$fullnames","1 = 1");
			}

			sql = sql.Replace("$this_usid",Convert.ToString(security.this_usid));
			sql = sql.Replace("$this_org",Convert.ToString(security.this_org));
			sql = sql.Replace("$og_external_user",Convert.ToString(security.this_external_user ? 1 : 0));
			sql = sql.Replace("$og_other_orgs_permission_level",Convert.ToString(security.this_other_orgs_permission_level));

			return dbutil.get_dataset(sql).Tables[0];

		}






		///////////////////////////////////////////////////////////////////////
		public static int get_default_user(int projectid)
		{

			if (projectid == 0) {return 0;}

			string sql = @"select isnull(pj_default_user,0)
					from projects
					where pj_id = $pj";

			sql = sql.Replace("$pj", Convert.ToString(projectid));
			DbUtil dbutil = new DbUtil();
			object obj = dbutil.execute_scalar(sql);

			if (obj != null)
			{
				return (int) obj;
			}
			else
			{
				return 0;
			}

		}

        ///////////////////////////////////////////////////////////////////////
        public static DataSet get_custom_columns(DbUtil dbutil)
        {

            return dbutil.get_dataset(
                @"/* custom columns */ select sc.name, st.[name] [datatype], sc.length, sc.xprec, sc.xscale, sc.isnullable,
				mm.text [default value],
				isnull(ccm_dropdown_type,'') [dropdown type],
				isnull(ccm_dropdown_vals,'') [vals],
				isnull(ccm_sort_seq, sc.colorder) [column order],
				sc.colorder
				from syscolumns sc
				inner join systypes st on st.xusertype = sc.xusertype
				inner join sysobjects so on sc.id = so.id
				left outer join syscomments mm on sc.cdefault = mm.id
				left outer join custom_col_metadata on ccm_colorder = sc.colorder
				where so.name = 'bugs'
				and st.[name] <> 'sysname'
				and sc.name not in ('rowguid',
				'bg_id',
				'bg_short_desc',
				'bg_reported_user',
				'bg_reported_date',
				'bg_project',
				'bg_org',
				'bg_category',
				'bg_priority',
				'bg_status',
				'bg_assigned_to_user',
				'bg_last_updated_user',
				'bg_last_updated_date',
				'bg_user_defined_attribute',
				'bg_project_custom_dropdown_value1',
				'bg_project_custom_dropdown_value2',
				'bg_project_custom_dropdown_value3')
				order by sc.id, isnull(ccm_sort_seq,sc.colorder)");

        }


		///////////////////////////////////////////////////////////////////////
		public static string run_svn(string args_without_password, string svn_username, string svn_password)
		{
			// run "svn.exe" and capture its output

			System.Diagnostics.Process p = new System.Diagnostics.Process();
			string svn_path = Util.get_setting("SubversionPathToSvn", "svn");
			p.StartInfo.FileName = svn_path;
			p.StartInfo.UseShellExecute = false;
			p.StartInfo.RedirectStandardOutput = true;
			p.StartInfo.RedirectStandardError = true;

			args_without_password += " --non-interactive";
			Util.write_to_log ("Subversion command:" + svn_path + " " + args_without_password);

			string args_with_password = args_without_password;

			if (svn_username != "")
			{
				args_with_password += " --username ";
				args_with_password += svn_username;
				args_with_password += " --password ";
				args_with_password += svn_password;
			}

			p.StartInfo.Arguments = args_with_password;
			p.Start();
			string stdout = p.StandardOutput.ReadToEnd();
			p.WaitForExit();
			stdout += p.StandardOutput.ReadToEnd();

			string error = p.StandardError.ReadToEnd();

			if (error != "")
			{
				Util.write_to_log(error);
				Util.write_to_log(stdout);
			}

			if (error != "")
            {
                string msg = "ERROR:";
                msg += "<div style='color:red; font-weight: bold; font-size: 10pt;'>";
                msg += "<br>Error executing svn.exe command from web server.";
                msg += "<br>" + error;
                msg += "<br>Arguments passed to svn.exe (except user/password):" + args_without_password;
                if (error.Contains("File not found"))
                {
                    msg += "<br><br>***** Has this file been deleted or renamed? See the following links:";
                    msg += "<br><a href=http://svn.collab.net/repos/svn/trunk/doc/user/svn-best-practices.html>http://svn.collab.net/repos/svn/trunk/doc/user/svn-best-practices.html</a>";
                    msg += "<br><a href=http://subversion.open.collab.net/articles/best-practices.html>http://subversion.open.collab.net/articles/best-practices.html</a>";
                    msg += "</div>";
                }
                return msg;
            }
			else
            {
				return stdout;
            }
		}

		public static void get_subversion_connection_info(
			DbUtil dbutil,
			int bugid,
    		ref string repository_url,
    		ref string svn_username,
    		ref string svn_password,
    		ref string websvn_url)
    	{
			repository_url = Util.get_setting("SubversionRepositoryUrl","");
			svn_username = Util.get_setting("SubversionUsername","");
			svn_password = Util.get_setting("SubversionPassword","");
			websvn_url = Util.get_setting("WebSvnUrl","");

			string sql = @"
			select isnull(pj_subversion_repository_url,'') [pj_subversion_repository_url],
			isnull(pj_subversion_username,'') [pj_subversion_username],
			isnull(pj_subversion_password,'') [pj_subversion_password],
			isnull(pj_websvn_url,'') [pj_websvn_url]
			from projects
			inner join bugs on pj_id = bg_project
			where bg_id = $bg";

			sql = sql.Replace("$bg",Convert.ToString(bugid));
			DataRow dr = dbutil.get_datarow(sql);

			if (dr == null)
			{
				return;
			}

			if ((string) dr["pj_subversion_repository_url"] != "")
			{
				repository_url = (string) dr["pj_subversion_repository_url"] ;
				svn_username = (string) dr["pj_subversion_username"] ;
				svn_password = (string) dr["pj_subversion_password"] ;
				websvn_url = (string) dr["pj_websvn_url"] ;
			}


		}


	} // end Util





	///////////////////////////////////////////////////////////////////////
	///////////////////////////////////////////////////////////////////////
	// SortableHtmlTable
	///////////////////////////////////////////////////////////////////////
	///////////////////////////////////////////////////////////////////////
	public class SortableHtmlTable
	{

		///////////////////////////////////////////////////////////////////////
		public static void create_from_dataset (
			HttpResponse r,
			DataSet ds,
			string edit_url,
			string delete_url)
		{
			create_from_dataset(r, ds, edit_url, delete_url, true);
		}


		///////////////////////////////////////////////////////////////////////
		public static void create_from_dataset (
			HttpResponse r,
			DataSet ds,
			string edit_url,
			string delete_url,
			bool html_encode)
		{
			create_start_of_table(r);
			create_headings(r, ds, edit_url, delete_url);
			create_body(r, ds, edit_url, delete_url, html_encode);
			create_end_of_table(r);
		}

		///////////////////////////////////////////////////////////////////////
		public static void create_start_of_table (
			HttpResponse r)
		{

			r.Write ("\n<div id=wait class=please_wait>&nbsp;</div>\n");
			r.Write ("<div class=click_to_sort>click on column headings to sort</div>\n");
			r.Write ("<div id=myholder>\n");
			//r.Write ("<table id=mytable class=datat border=1 cellspacing=0 cellpadding=2>\n");
			r.Write ("<table id=mytable border=1 class=datat>\n");

		}

		///////////////////////////////////////////////////////////////////////
		public static void create_end_of_table (
			HttpResponse r)
		{

			// data
			r.Write ("</table>\n");
			r.Write ("</div>\n");
			r.Write ("<div id=sortedby>&nbsp;</div>\n");

		}

		///////////////////////////////////////////////////////////////////////
		// headings
		///////////////////////////////////////////////////////////////////////
		public static void create_headings (
			HttpResponse r,
			DataSet ds,
			string edit_url,
			string delete_url)
		{

			r.Write ("<tr>\n");

			int db_column_count = 0;

			foreach (DataColumn dc in ds.Tables[0].Columns)
			{

				if ((edit_url != "" || delete_url != "")
				&& db_column_count == (ds.Tables[0].Columns.Count - 1))
				{
					if (edit_url != "")
					{
						r.Write ("<td class=datah valign=bottom>edit</td>");
					}
					if (delete_url != "")
					{
						r.Write ("<td class=datah valign=bottom>delete</td>");
					}

				}
				else
				{

					// determine data type
					string datatype = "";
					if (Util.is_numeric_datatype(dc.DataType.ToString()))
					{
						datatype = "num";
					}
					else if (dc.DataType.ToString() == "System.DateTime")
					{
						datatype = "date";
					}
					else
					{
						datatype = "str";
					}

					r.Write ("<td class=datah valign=bottom>\n");

					if (dc.ColumnName.StartsWith("$no_sort_"))
					{
						r.Write(dc.ColumnName.Replace("$no_sort_",""));
					}
					else
					{
						string sortlink = "<a href='javascript: sort_by_col($col, \"$type\")'>";
						sortlink = sortlink.Replace("$col", Convert.ToString(db_column_count));
						sortlink = sortlink.Replace("$type", datatype);
						r.Write (sortlink);
						r.Write (dc.ColumnName);
						r.Write ("</a>");
					}

					//r.Write ("<br>"); // for debugging
					//r.Write (dc.DataType);

					r.Write ("</td>\n");

				}

				db_column_count++;

			}
			r.Write ("</tr>\n");

		}


		///////////////////////////////////////////////////////////////////////
		// body, data
		///////////////////////////////////////////////////////////////////////
		public static void create_body (
			HttpResponse r,
			DataSet ds,
			string edit_url,
			string delete_url,
			bool html_encode)
		{

			foreach (DataRow dr in ds.Tables[0].Rows)
			{
				r.Write ("\n<tr>");
				for(int i = 0; i < ds.Tables[0].Columns.Count; i++)
				{
					string datatype = ds.Tables[0].Columns[i].DataType.ToString();

					if ((edit_url != "" || delete_url != "")
					&& i == (ds.Tables[0].Columns.Count - 1))
					{
						if (edit_url != "")
						{
							r.Write ("<td class=datad><a href="
								+ edit_url + dr[ds.Tables[0].Columns.Count - 1] + ">edit</a></td>");
						}
						if (delete_url != "")
						{
							r.Write ("<td class=datad><a href="
								+ delete_url + dr[ds.Tables[0].Columns.Count - 1] + ">delete</a></td>");
						}
					}
					else
					{
						if (Util.is_numeric_datatype(datatype))
						{
							r.Write ("<td class=datad align=right>");
						}
						else
						{
							r.Write ("<td class=datad>");
						}
						if (dr[i].ToString() == "")
						{
							r.Write("&nbsp;");
						}
						else
						{
							if (datatype == "System.DateTime")
							{
								r.Write (Util.format_db_date(dr[i]));
							}
							else
							{
								if (html_encode)
								{
									r.Write (HttpUtility.HtmlEncode(dr[i].ToString()));
								}
								else
								{
									r.Write (dr[i]);
								}
							}
						}
						r.Write ("</td>");
					}

				}
				r.Write ("</tr>\n");
			}

		}
	} // end SortableHtmlTable



	///////////////////////////////////////////////////////////////////////
	///////////////////////////////////////////////////////////////////////
	// DbUtil
	///////////////////////////////////////////////////////////////////////
	///////////////////////////////////////////////////////////////////////
	public class DbUtil {

		//public SqlConnection sqlconn;
		public string connection_string;

		///////////////////////////////////////////////////////////////////////
		public DataSet command_to_dataset(SqlCommand cmd)
		{

			DataSet ds = new DataSet();
			SqlDataAdapter da = new SqlDataAdapter(cmd);
			da.Fill(ds);
			return ds;

		}

		///////////////////////////////////////////////////////////////////////
		public object execute_scalar(string sql)
		{
			if (Util.get_setting("LogSqlEnabled","1") == "1")
			{
				Util.write_to_log("sql=\n" + sql);
			}

			using (SqlConnection conn = get_sqlconnection())
			{
				object returnValue;
				conn.Open();
				SqlCommand cmd = new SqlCommand (sql, conn);
				returnValue = cmd.ExecuteScalar();
				conn.Close();
                return returnValue;
			}
		}

		///////////////////////////////////////////////////////////////////////
        public object execute_scalar(SqlCommand cmd)
        {
            log_command(cmd);

            using (SqlConnection conn = get_sqlconnection())
            {
                try
                {
                    cmd.Connection = conn;
                    object returnValue;
                    conn.Open();
                    returnValue = cmd.ExecuteScalar();
                    conn.Close();
                    return returnValue;
                }
                finally
                {
                    cmd.Connection = null;
                }
            }
        }

		///////////////////////////////////////////////////////////////////////
		public void execute_nonquery(string sql)
		{

			if (Util.get_setting("LogSqlEnabled","1") == "1")
			{
				Util.write_to_log("sql=\n" + sql);
			}

			using (SqlConnection conn = get_sqlconnection())
			{
				conn.Open();
				SqlCommand cmd = new SqlCommand (sql, conn);
				cmd.ExecuteNonQuery();
				conn.Close();
			}
		}

		///////////////////////////////////////////////////////////////////////
        public void execute_nonquery(SqlCommand cmd)
        {
            log_command(cmd);

            using (SqlConnection conn = get_sqlconnection())
            {
                try
                {
                    cmd.Connection = conn;
                    conn.Open();
                    cmd.ExecuteNonQuery();
                    conn.Close();
                }
                finally
                {
                    cmd.Connection = null;
                }
            }
        }

        ///////////////////////////////////////////////////////////////////////
        public SqlDataReader execute_reader(string sql, CommandBehavior behavior)
        {
            if (Util.get_setting("LogSqlEnabled", "1") == "1")
            {
                Util.write_to_log("sql=\n" + sql);
            }

            SqlConnection conn = get_sqlconnection();
            try
            {
                using (SqlCommand cmd = new SqlCommand(sql, conn))
                {
                    conn.Open();
                    return cmd.ExecuteReader(behavior | CommandBehavior.CloseConnection);
                }
            }
            catch
            {
                conn.Close();
                throw;
            }
        }

        ///////////////////////////////////////////////////////////////////////
        public SqlDataReader execute_reader(SqlCommand cmd, CommandBehavior behavior)
        {
            log_command(cmd);

            SqlConnection conn = get_sqlconnection();
            try
            {
                cmd.Connection = conn;
                conn.Open();
                return cmd.ExecuteReader(behavior | CommandBehavior.CloseConnection);
            }
            catch
            {
                conn.Close();
                throw;
            }
            finally
            {
                cmd.Connection = null;
            }
        }

		///////////////////////////////////////////////////////////////////////
		public DataSet get_dataset(string sql)
		{

			if (Util.get_setting("LogSqlEnabled","1") == "1")
			{
				Util.write_to_log("sql=\n" + sql);
			}

			DataSet ds = new DataSet();
			using (SqlConnection conn = get_sqlconnection())
			{
				SqlDataAdapter da = new SqlDataAdapter(sql, conn);
				da.Fill(ds);
				return ds;
			}
		}

		///////////////////////////////////////////////////////////////////////
		public SqlConnection get_sqlconnection()
		{

			connection_string = Util.get_setting("ConnectionString","MISSING CONNECTION STRING");
			SqlConnection sqlconn = new SqlConnection(connection_string);
			return sqlconn;

		}

		///////////////////////////////////////////////////////////////////////
		public DataView get_dataview(string sql)
		{
			DataSet ds = get_dataset(sql);
			return new DataView (ds.Tables[0]);
		}


		///////////////////////////////////////////////////////////////////////
		public DataRow get_datarow(string sql)
		{
			DataSet ds = get_dataset(sql);
			if (ds.Tables[0].Rows.Count != 1) {
				return null;
			}
			else
			{
				return ds.Tables[0].Rows[0];
			}
		}

        ///////////////////////////////////////////////////////////////////////
        public void log_command(SqlCommand cmd)
        {
            if (Util.get_setting("LogSqlEnabled", "1") == "1")
            {
                StringBuilder sb = new StringBuilder();
                sb.Append("sql=\n" + cmd.CommandText);
                foreach (SqlParameter param in cmd.Parameters)
                {
                    sb.Append("\n  ");
                    sb.Append(param.ParameterName);
                    sb.Append("=");
                    if (param.Value == null || Convert.IsDBNull(param.Value))
                    {
                        sb.Append("null");
                    }
                    else if (param.SqlDbType == SqlDbType.Text || param.SqlDbType == SqlDbType.Image)
                    {
                        sb.Append("...");
                    }
                    else
                    {
                        sb.Append("\"");
                        sb.Append(param.Value);
                        sb.Append("\"");
                    }
                }
                Util.write_to_log(sb.ToString());
            }
        }

	} // end DbUtil


	///////////////////////////////////////////////////////////////////////
	///////////////////////////////////////////////////////////////////////
	// PrintBug
	///////////////////////////////////////////////////////////////////////
	///////////////////////////////////////////////////////////////////////
	public class PrintBug {

		///////////////////////////////////////////////////////////////////////
		public static void print_bug (HttpResponse Response, DataRow dr, bool this_is_admin, bool this_external_user)
		{

			int bugid = Convert.ToInt32(dr["id"]);
			string string_bugid = Convert.ToString(bugid);

			Response.Write ("<style>");
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
			Response.Write ("\n");

			if (System.IO.File.Exists(path_custom))
			{
				Response.WriteFile(path_custom);
			}
			else
			{
				Response.WriteFile(HttpContext.Current.Server.MapPath("./custom/") + "btnet_custom.css");
			}

			// underline links in the emails to make them more obvious
			Response.Write ("\na {text-decoration: underline; }");
			Response.Write ("\na:visited {text-decoration: underline; }");
			Response.Write("\na:hover {text-decoration: underline; }");
			Response.Write ("\n</style>");


			Response.Write ("<body style=background:white>");
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

			Response.Write ("<table border=1 cellpadding=3 cellspacing=0>");
			Response.Write ("<tr><td>Last changed by<td>"
				+ btnet.Util.format_username((string)dr["last_updated_user"],(string)dr["last_updated_fullname"])
				+ "&nbsp;");
			Response.Write ("<tr><td>Reported By<td>"
				+ btnet.Util.format_username((string)dr["reporter"],(string)dr["reporter_fullname"])
				+ "&nbsp;");
			Response.Write ("<tr><td>Reported On<td>" + btnet.Util.format_db_date(dr["reported_date"]) + "&nbsp;");
			Response.Write ("<tr><td>Project<td>" + dr["current_project"] + "&nbsp;");
			Response.Write ("<tr><td>Organization<td>" + dr["og_name"] + "&nbsp;");
			Response.Write ("<tr><td>Category<td>" + dr["category_name"] + "&nbsp;");
			Response.Write ("<tr><td>Priority<td>" + dr["priority_name"] + "&nbsp;");
			Response.Write ("<tr><td>Assigned<td>"
				+ btnet.Util.format_username((string)dr["assigned_to_username"],(string)dr["assigned_to_fullname"])
				+ "&nbsp;");
			Response.Write ("<tr><td>Status<td>" + dr["status_name"] + "&nbsp;");

			if (btnet.Util.get_setting("ShowUserDefinedBugAttribute","1") == "1")
			{
				Response.Write ("<tr><td>"
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
				Response.Write ("<tr><td>");
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
							Response.Write ("<tr><td>");
							Response.Write (project_dr["pj_custom_dropdown_label" + Convert.ToString(i)]);
							Response.Write ("<td>");
							Response.Write (dr["bg_project_custom_dropdown_value"  + Convert.ToString(i)]);
							Response.Write ("&nbsp;");
						}
					}
				}
			}



			Response.Write("</table><p>");

			Response.Write ("<p><table border=1 cellspacing=0 cellpadding=4>");


			// don't write links, don't show images, do show update history
			write_posts (Response, bugid, 0, false, false, true,
				this_is_admin,
				false,
				this_external_user);

			Response.Write ("</table>");

			Response.Write ("<div class=align><table border=0><tr><td></table></div></body>");

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

			Response.Write ("<table id='posts_table' border=0 cellpadding=0 cellspacing=3>");
			DataSet ds_posts = btnet.Bug.get_bug_posts(bugid);

			int bp_id;
			int prev_bp_id = -1;
			foreach (DataRow dr in ds_posts.Tables[0].Rows)
			{

				Response.Write ("\n");

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
						Response.Write ("</table>");
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

				Response.Write ("\n");

			}
			Response.Write ("</table></table>");
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

			Response.Write ("\n<tr><td class=cmt><table width=100% ><tr><td align=left>");


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
				Response.Write (btnet.Util.format_email_username(
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
					Response.Write (btnet.Util.format_email_to(
						bugid,
						HttpUtility.HtmlEncode((string)dr["bp_email_to"])));
				}
				else
				{
					Response.Write (HttpUtility.HtmlEncode((string)dr["bp_email_to"]));
				}

				Response.Write (" by ");

				Response.Write (btnet.Util.format_email_username(
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
					Response.Write (btnet.Util.format_email_from(
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
				Response.Write (btnet.Util.format_email_username(
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
				Response.Write (btnet.Util.format_email_username(
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
			Response.Write ("</span></td>");


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

			Response.Write ("</td></td></tr></table><table border=0>\n<tr><td>");
			// the text itself
			string comment = (string) dr["bp_comment"];
			string comment_type = (string) dr["bp_content_type"];
			comment = btnet.Util.format_comment(comment, comment_type);


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

			Response.Write ("<p><span class=pst>");
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


	} // end PrintBug


	///////////////////////////////////////////////////////////////////////
	///////////////////////////////////////////////////////////////////////
	// Email
	///////////////////////////////////////////////////////////////////////
	///////////////////////////////////////////////////////////////////////
	public class Email {
		///////////////////////////////////////////////////////////////////////
		public static string send_email( // 5 args
			string to,
			string from,
			string cc,
			string subject,
			string body)
		{
			return send_email(
				to,
				from,
				cc,
				subject,
				body,
				System.Web.Mail.MailFormat.Text,
				System.Web.Mail.MailPriority.Normal,
				null,
				false);
		}

		///////////////////////////////////////////////////////////////////////
		public static string send_email( // 6 args
			string to,
			string from,
			string cc,
			string subject,
			string body,
			System.Web.Mail.MailFormat body_format)
		{
			return send_email(
				to,
				from,
				cc,
				subject,
				body,
				body_format,
				System.Web.Mail.MailPriority.Normal,
				null,
				false);
		}

		///////////////////////////////////////////////////////////////////////
		public static string send_email(
			string to,
			string from,
			string cc,
			string subject,
			string body,
			System.Web.Mail.MailFormat body_format,
			System.Web.Mail.MailPriority priority,
			int[] attachment_bpids,
			bool return_receipt)
		{
			ArrayList files_to_delete = new ArrayList();
			ArrayList directories_to_delete = new ArrayList();
			System.Web.Mail.MailMessage msg = new System.Web.Mail.MailMessage();
			msg.To = to;
			msg.From = from;
			msg.Cc = cc;
			msg.Subject = subject;
			msg.Priority = priority;

			// This fixes a bug for a couple people, but make it configurable, just in case.
			if (Util.get_setting("BodyEncodingUTF8", "1") == "1")
			{
				msg.BodyEncoding = Encoding.UTF8;
			}


			if (return_receipt)
			{
				msg.Headers.Add("Disposition-Notification-To", from);
			}

			// workaround for a bug I don't understand...
			if (Util.get_setting("SmtpForceReplaceOfBareLineFeeds", "0") == "1")
			{
				body = body.Replace("\n", "\r\n");
			}

			msg.Body = body;
			msg.BodyFormat = body_format;


			string smtp_server = Util.get_setting("SmtpServer", "");
			if (smtp_server != "")
			{
				System.Web.Mail.SmtpMail.SmtpServer = smtp_server;
			}

			string smtp_password = Util.get_setting("SmtpServerAuthenticatePassword", "");

			if (smtp_password != "")
			{
				msg.Fields["http://schemas.microsoft.com/cdo/configuration/sendpassword"] = smtp_password;
				msg.Fields["http://schemas.microsoft.com/cdo/configuration/smtpauthenticate"] = 1;
				msg.Fields["http://schemas.microsoft.com/cdo/configuration/sendusername"] =
					Util.get_setting("SmtpServerAuthenticateUser", "");
			}

			string smtp_pickup = Util.get_setting("SmtpServerPickupDirectory", "");
			if (smtp_pickup != "")
			{
				msg.Fields["http://schemas.microsoft.com/cdo/configuration/smtpserverpickupdirectory"] = smtp_pickup;
			}


			string send_using = Util.get_setting("SmtpSendUsing", "");
			if (send_using != "")
			{
				msg.Fields["http://schemas.microsoft.com/cdo/configuration/sendusing"] = send_using;
			}


			string smtp_use_ssl = Util.get_setting("SmtpUseSSL", "");
			if (smtp_use_ssl == "1")
			{
				msg.Fields["http://schemas.microsoft.com/cdo/configuration/smtpusessl"] = "true";
			}

			string smtp_server_port = Util.get_setting("SmtpServerPort", "");
			if (smtp_server_port != "")
			{
				msg.Fields["http://schemas.microsoft.com/cdo/configuration/smtpserverport"] = smtp_server_port;
			}

			if (attachment_bpids != null)
			{
				string tempDirectory = Path.Combine(Path.GetTempPath(), Path.GetRandomFileName());
				Directory.CreateDirectory(tempDirectory);
				directories_to_delete.Add(tempDirectory);

				foreach (int attachment_bpid in attachment_bpids)
				{
					byte[] buffer = new byte[16 * 1024];
					string dest_path_and_filename;
					Bug.BugPostAttachment bpa = Bug.get_bug_post_attachment(attachment_bpid);
					using (bpa.content)
					{
						dest_path_and_filename = Path.Combine(tempDirectory, bpa.file);
						using (FileStream out_stream = new FileStream(dest_path_and_filename, FileMode.CreateNew, FileAccess.Write, FileShare.None))
						{
							int bytes_read = bpa.content.Read(buffer, 0, buffer.Length);
							while (bytes_read != 0)
							{
								out_stream.Write(buffer, 0, bytes_read);

								bytes_read = bpa.content.Read(buffer, 0, buffer.Length);
							}
						}

					}

					System.Web.Mail.MailAttachment mail_attachment = new System.Web.Mail.MailAttachment(
						dest_path_and_filename,
						System.Web.Mail.MailEncoding.Base64);
					msg.Attachments.Add(mail_attachment);
					files_to_delete.Add(dest_path_and_filename);
				}
			}


			try
			{
				System.Web.Mail.SmtpMail.Send(msg);

				// We delete late here because testing showed that SmtpMail class
				// got confused when we deleted too soon.
				if (files_to_delete.Count > 0)
				{
					foreach (string file in files_to_delete)
					{
						File.Delete(file);
					}
				}

				if (directories_to_delete.Count > 0)
				{
					foreach (string directory in directories_to_delete)
					{
						Directory.Delete(directory);
					}
				}

				return "";
			}
			catch (Exception e)
			{
				Util.write_to_log("There was a problem sending email.   Check settings in Web.config.");
				Util.write_to_log("TO:" + to);
				Util.write_to_log("FROM:" + from);
				Util.write_to_log("SUBJECT:" + subject);
				Util.write_to_log(e.GetBaseException().Message.ToString());
				return (e.GetBaseException().Message);
			}

		}

	} // end Email

	///////////////////////////////////////////////////////////////////////
	///////////////////////////////////////////////////////////////////////
	// Bug
	///////////////////////////////////////////////////////////////////////
	///////////////////////////////////////////////////////////////////////
	public class Bug
	{

		public const int INSERT = 1;
		public const int UPDATE = 2;


		///////////////////////////////////////////////////////////////////////
		public static void auto_subscribe(int bugid)
		{

			// clean up bug subscriptions that no longer fit security rules
			// subscribe per auto_subscribe
			// subscribe project's default user
			// subscribe per-project auto_subscribers
			// subscribe per auto_subscribe_own_bugs
			string sql = @"
declare @pj int
select @pj = bg_project from bugs where bg_id = $id

delete from bug_subscriptions
where bs_bug = $id
and bs_user in
	(select x.pu_user
	from projects
	left outer join project_user_xref x on pu_project = pj_id
	where pu_project = @pj
	and isnull(pu_permission_level,$dpl) = 0)

delete from bug_subscriptions
where bs_bug = $id
and bs_user in
	(select us_id from users
	 inner join orgs on us_org = og_id
	 inner join bugs on bg_id = $id
	 where og_other_orgs_permission_level = 0
	 and bg_org <> og_id)

insert into bug_subscriptions (bs_bug, bs_user)
select $id, us_id
from users
inner join orgs on us_org = og_id
inner join bugs on bg_id = $id
left outer join project_user_xref on pu_project = @pj and pu_user = us_id
where us_auto_subscribe = 1
and
	case
		when
			us_org <> bg_org
			and og_other_orgs_permission_level < 2
			and og_other_orgs_permission_level < isnull(pu_permission_level,$dpl)
				then og_other_orgs_permission_level
		else
			isnull(pu_permission_level,$dpl)
	end <> 0
and us_active = 1
and us_id not in
(select bs_user from bug_subscriptions
where bs_bug = $id)

insert into bug_subscriptions (bs_bug, bs_user)
select $id, pj_default_user
from projects
inner join users on pj_default_user = us_id
where pj_id = @pj
and pj_default_user <> 0
and pj_auto_subscribe_default_user = 1
and us_active = 1
and pj_default_user not in
(select bs_user from bug_subscriptions
where bs_bug = $id)

insert into bug_subscriptions (bs_bug, bs_user)
select $id, pu_user from project_user_xref
inner join users on pu_user = us_id
inner join orgs on us_org = og_id
inner join bugs on bg_id = $id
where pu_auto_subscribe = 1
and
	case
		when
			us_org <> bg_org
			and og_other_orgs_permission_level < 2
			and og_other_orgs_permission_level < isnull(pu_permission_level,$dpl)
				then og_other_orgs_permission_level
		else
			isnull(pu_permission_level,$dpl)
	end <> 0
and us_active = 1
and pu_project = @pj
and pu_user not in
(select bs_user from bug_subscriptions
where bs_bug = $id)

insert into bug_subscriptions (bs_bug, bs_user)
select $id, us_id
from users
inner join bugs on bg_id = $id
inner join orgs on us_org = og_id
left outer join project_user_xref on pu_project = @pj and pu_user = us_id
where ((us_auto_subscribe_own_bugs = 1 and bg_assigned_to_user = us_id)
	or
	(us_auto_subscribe_reported_bugs = 1 and bg_reported_user = us_id))
and
	case
		when
			us_org <> bg_org
			and og_other_orgs_permission_level < 2
			and og_other_orgs_permission_level < isnull(pu_permission_level,$dpl)
				then og_other_orgs_permission_level
		else
			isnull(pu_permission_level,$dpl)
	end <> 0
and us_active = 1
and us_id not in
(select bs_user from bug_subscriptions
where bs_bug = $id)";

            sql = sql.Replace("$id", Convert.ToString(bugid));
            sql = sql.Replace("$dpl", btnet.Util.get_setting("DefaultPermissionLevel", "2"));

            DbUtil dbutil = new DbUtil();
            dbutil.execute_nonquery(sql);


        }

        ///////////////////////////////////////////////////////////////////////
        public static void delete_bug(int bugid)
        {

            // delete attachements

            string id = Convert.ToString(bugid);

            string upload_folder = Util.get_upload_folder();
            string sql = @"select bp_id, bp_file from bug_posts where bp_type = 'file' and bp_bug = $bg";
            sql = sql.Replace("$bg", id);

            DbUtil dbutil = new DbUtil();
            DataSet ds = dbutil.get_dataset(sql);
            if (upload_folder != null)
            {
            foreach (DataRow dr in ds.Tables[0].Rows)
            {

                // create path
                StringBuilder path = new StringBuilder(upload_folder);
                path.Append("\\");
                path.Append(id);
                path.Append("_");
                path.Append(Convert.ToString(dr["bp_id"]));
                path.Append("_");
                path.Append(Convert.ToString(dr["bp_file"]));
                if (System.IO.File.Exists(path.ToString()))
                {
                    System.IO.File.Delete(path.ToString());
                }

            }
            }

            // delete the database entries

            sql = @"delete bug_post_attachments from bug_post_attachments inner join bug_posts on bug_post_attachments.bpa_post = bug_posts.bp_id where bug_posts.bp_bug = $bg
                delete from bug_posts where bp_bug = $bg
				delete from bug_subscriptions where bs_bug = $bg
				delete from bug_relationships where re_bug1 = $bg
				delete from bug_relationships where re_bug2 = $bg
				delete from bugs where bg_id = $bg";

            sql = sql.Replace("$bg", id);
            dbutil.execute_nonquery(sql);


        }

        ///////////////////////////////////////////////////////////////////////
        public static int insert_post_attachment_copy(
            btnet.Security security,
            int bugid,
			int copy_bpid,
			string comment,
			int parent,
			bool hidden_from_external_users,
			bool send_notifications)
        {
            return insert_post_attachment_impl(
                security,
				bugid,
				null,
				-1,
				copy_bpid,
				null,
				comment,
				null,
				parent,
				hidden_from_external_users,
				send_notifications);
        }

        ///////////////////////////////////////////////////////////////////////
        public static int insert_post_attachment(
            btnet.Security security,
			int bugid,
			Stream content,
			int content_length,
			string file,
			string comment,
			string content_type,
			int parent,
			bool hidden_from_external_users,
			bool send_notifications)
        {
            return insert_post_attachment_impl(
                security,
				bugid,
				content,
				content_length,
				-1, // copy_bpid
				file,
				comment,
				content_type,
				parent,
				hidden_from_external_users,
				send_notifications);
        }

        ///////////////////////////////////////////////////////////////////////
        private static int insert_post_attachment_impl(
            btnet.Security security,
			int bugid,
			Stream content,
			int content_length,
			int copy_bpid,
			string file,
			string comment,
			string content_type,
			int parent,
			bool hidden_from_external_users,
			bool send_notifications)
        {
            // Note that this method does not perform any security check nor does
            // it check that content_length is less than MaxUploadSize.
            // These are left up to the caller.

            DbUtil dbutil = new DbUtil();
            string upload_folder = Util.get_upload_folder();
            string sql;
            bool store_attachments_in_database = (Util.get_setting("StoreAttachmentsInDatabase", "0") == "1");
            string effective_file = file;
            int effective_content_length = content_length;
            string effective_content_type = content_type;
            Stream effective_content = null;

            try
            {
                // Determine the content. We may be instructed to copy an existing
                // attachment via copy_bpid, or a Stream may be provided as the content parameter.

                if (copy_bpid != -1)
                {
                    BugPostAttachment bpa = get_bug_post_attachment(copy_bpid);

                    effective_content = bpa.content;
                    effective_file = bpa.file;
                    effective_content_length = bpa.content_length;
                    effective_content_type = bpa.content_type;
                }
                else
                {
                    effective_content = content;
                    effective_file = file;
                    effective_content_length = content_length;
                    effective_content_type = content_type;
                }

                // Insert a new post into bug_posts.

                sql = @"insert into bug_posts
			            (bp_type, bp_bug, bp_file, bp_comment, bp_size, bp_date, bp_user, bp_content_type, bp_parent, bp_hidden_from_external_users)
			            values ('file', $bg, N'$fi', N'$de', $si, getdate(), $us, N'$ct', $pa, $internal)
			            select scope_identity()";

                sql = sql.Replace("$bg", Convert.ToString(bugid));
                sql = sql.Replace("$fi", effective_file.Replace("'", "''"));
                sql = sql.Replace("$de", comment.Replace("'", "''"));
                sql = sql.Replace("$si", Convert.ToString(effective_content_length));
                sql = sql.Replace("$us", Convert.ToString(security.this_usid));
                sql = sql.Replace("$ct", effective_content_type.Replace("'", "''"));
                if (parent == -1)
                {
                    sql = sql.Replace("$pa", "null");
                }
                else
                {
                    sql = sql.Replace("$pa", Convert.ToString(parent));
                }
                sql = sql.Replace("$internal", btnet.Util.bool_to_string(hidden_from_external_users));

                int bp_id = Convert.ToInt32(dbutil.execute_scalar(sql));

                try
                {
                    // Store attachment in bug_post_attachments table.

                    if (store_attachments_in_database)
                    {
                        byte[] data = new byte[effective_content_length];
                        int bytes_read = 0;

                        while (bytes_read < effective_content_length)
                        {
                            int bytes_read_this_iteration = effective_content.Read(data, bytes_read, effective_content_length - bytes_read);
                            if (bytes_read_this_iteration == 0)
                            {
                                throw new Exception("Unexpectedly reached the end of the stream before all data was read.");
                            }
                            bytes_read += bytes_read_this_iteration;
                        }

                        sql = @"insert into bug_post_attachments
                                (bpa_post, bpa_content)
                                values (@bp, @bc)";
                        using (SqlCommand cmd = new SqlCommand(sql))
                        {
                            cmd.Parameters.AddWithValue("@bp", bp_id);
                            cmd.Parameters.Add("@bc", SqlDbType.Image).Value = data;
                            dbutil.execute_nonquery(cmd);
                        }
                    }
                    else
                    {
                        // Store attachment in UploadFolder.

                        if (upload_folder == null)
                        {
                            throw new Exception("StoreAttachmentsInDatabase is false and UploadFolder is not set in web.config.");
                        }

                        // Copy the content Stream to a file in the upload_folder.
                        byte[] buffer = new byte[16384];
                        int bytes_read = 0;
                        using (FileStream fs = new FileStream(upload_folder + "\\" + bugid + "_" + bp_id + "_" + effective_file, FileMode.CreateNew, FileAccess.Write))
                        {
                            while (bytes_read < effective_content_length)
                            {
                                int bytes_read_this_iteration = effective_content.Read(buffer, 0, buffer.Length);
                                if (bytes_read_this_iteration == 0)
                                {
                                    throw new Exception("Unexpectedly reached the end of the stream before all data was read.");
                                }
                                fs.Write(buffer, 0, bytes_read_this_iteration);
                                bytes_read += bytes_read_this_iteration;
                            }
                        }
                    }
                }
                catch
                {
                    // clean up
                    sql = @"delete from bug_posts where bp_id = $bp";

                    sql = sql.Replace("$bp", Convert.ToString(bp_id));

                    dbutil.execute_nonquery(sql);

                    throw;
                }

                if (send_notifications)
                {
					btnet.Bug.send_notifications(btnet.Bug.UPDATE, bugid, security);
                }
                return bp_id;
            }
            finally
            {
                // If this procedure "owns" the content (instead of our caller owning it), dispose it.
                if (effective_content != null && effective_content != content)
                {
                    effective_content.Dispose();
                }
            }
        }

        public class BugPostAttachment
        {
            public BugPostAttachment(string file, Stream content, int content_length, string content_type)
            {
                this.file = file;
                this.content = content;
                this.content_length = content_length;
                this.content_type = content_type;
            }

            public string file;
            public Stream content;
            public int content_length;
            public string content_type;
        }

        ///////////////////////////////////////////////////////////////////////
        public static BugPostAttachment get_bug_post_attachment(int bp_id)
        {
            // Note that this method does not perform any security check.
            // This is left up to the caller.

            DbUtil dbutil = new DbUtil();
            string upload_folder = Util.get_upload_folder();
            string sql;
            bool store_attachments_in_database = (Util.get_setting("StoreAttachmentsInDatabase", "0") == "1");
            int bugid;
            string file;
            int content_length;
            string content_type;
            Stream content = null;

            try
            {
                sql = @"select bp_bug, bp_file, bp_size, bp_content_type
                        from bug_posts
                        where bp_id = $bp";
                sql = sql.Replace("$bp", Convert.ToString(bp_id));
                using (SqlDataReader reader = dbutil.execute_reader(sql, CommandBehavior.CloseConnection))
                {
                    if (reader.Read())
                    {
                        bugid = reader.GetInt32(reader.GetOrdinal("bp_bug"));
                        file = reader.GetString(reader.GetOrdinal("bp_file"));
                        content_length = reader.GetInt32(reader.GetOrdinal("bp_size"));
                        content_type = reader.GetString(reader.GetOrdinal("bp_content_type"));
                    }
                    else
                    {
                        throw new Exception("Existing bug post not found.");
                    }
                }

                sql = @"select bpa_content
                            from bug_post_attachments
                            where bpa_post = $bp";
                sql = sql.Replace("$bp", Convert.ToString(bp_id));

                object content_object;
                content_object = dbutil.execute_scalar(sql);

                if (content_object != null && !Convert.IsDBNull(content_object))
                {
                    content = new MemoryStream((byte[])content_object);
                }
                else
                {
                    // Could not find in bug_post_attachments. Try the upload_folder.
                    if (upload_folder == null)
                    {
                        throw new Exception("The attachment could not be found in the database and UploadFolder is not set in web.config.");
                    }

                    string upload_folder_filename = upload_folder + "\\" + bugid + "_" + bp_id + "_" + file;
                    if (File.Exists(upload_folder_filename))
                    {
                        content = new FileStream(upload_folder_filename, FileMode.Open, FileAccess.Read, FileShare.Read);
                    }
                    else
                    {
                        throw new Exception("Attachment not found in database or UploadFolder.");
                    }
                }

                return new BugPostAttachment(file, content, content_length, content_type);
            }
            catch
            {
                if (content != null)
                    content.Dispose();

                throw;
            }
        }

        ///////////////////////////////////////////////////////////////////////
        public static DataRow get_bug_datarow(
            int bugid,
            Security security)
        {

            DbUtil dbutil = new DbUtil();
            DataSet ds_custom_cols = btnet.Util.get_custom_columns(dbutil);
            return get_bug_datarow(bugid, security, ds_custom_cols);
        }


        ///////////////////////////////////////////////////////////////////////
        public static DataRow get_bug_datarow(
            int bugid,
            Security security,
            DataSet ds_custom_cols)
        {
            string sql = @" /* get_bug_datarow */
declare @revision int
set @revision = 0";

   			if (btnet.Util.get_setting("EnableSubversionIntegration","0") == "1")
            {
				sql += @"
select @revision = count(1)
	from svn_affected_paths
	inner join svn_revisions on svnap_svnrev_id = svnrev_id
	where svnrev_bug = $id;";
			}

            sql += @"
declare @related int;
select @related = count(1)
	from bug_relationships
	where re_bug1 = $id;

select bg_id [id],
bg_short_desc [short_desc],
isnull(ru.us_username,'[deleted user]') [reporter],
case rtrim(ru.us_firstname)
	when null then isnull(ru.us_lastname, '')
	when '' then isnull(ru.us_lastname, '')
	else isnull(ru.us_lastname + ', ' + ru.us_firstname,'')
end [reporter_fullname],
bg_reported_date [reported_date],
isnull(lu.us_username,'') [last_updated_user],
case rtrim(lu.us_firstname)
	when null then isnull(lu.us_lastname, '')
	when '' then isnull(lu.us_lastname, '')
	else isnull(lu.us_lastname + ', ' + lu.us_firstname,'')
end [last_updated_fullname],


bg_last_updated_date [last_updated_date],
isnull(bg_project,0) [project],
isnull(pj_name,'[no project]') [current_project],

isnull(bg_org,0) [organization],
isnull(bugorg.og_name,'') [og_name],

isnull(bg_category,0) [category],
isnull(ct_name,'') [category_name],

isnull(bg_priority,0) [priority],
isnull(pr_name,'') [priority_name],

isnull(bg_status,0) [status],
isnull(st_name,'') [status_name],

isnull(bg_user_defined_attribute,0) [udf],
isnull(udf_name,'') [udf_name],

isnull(bg_assigned_to_user,0) [assigned_to_user],
isnull(asg.us_username,'[not assigned]') [assigned_to_username],
case rtrim(asg.us_firstname)
	when null then isnull(asg.us_lastname, '[not assigned]')
	when '' then isnull(asg.us_lastname, '[not assigned]')
	else isnull(asg.us_lastname + ', ' + asg.us_firstname,'[not assigned]')
end [assigned_to_fullname],

isnull(bs_id,0) [subscribed],

case
	when
		$this_org <> bg_org
		and userorg.og_other_orgs_permission_level < 2
		and userorg.og_other_orgs_permission_level < isnull(pu_permission_level,$dpl)
			then userorg.og_other_orgs_permission_level
	else
		isnull(pu_permission_level,$dpl)
end [pu_permission_level],

isnull(bg_project_custom_dropdown_value1,'') [bg_project_custom_dropdown_value1],
isnull(bg_project_custom_dropdown_value2,'') [bg_project_custom_dropdown_value2],
isnull(bg_project_custom_dropdown_value3,'') [bg_project_custom_dropdown_value3],
@related [relationship_cnt],
@revision [revision_cnt],
getdate() [snapshot_timestamp]
$custom_cols_placeholder
from bugs
inner join users this_user on us_id = $this_usid
inner join orgs userorg on this_user.us_org = userorg.og_id
left outer join user_defined_attribute on bg_user_defined_attribute = udf_id
left outer join projects on bg_project = pj_id
left outer join orgs bugorg on bg_org = bugorg.og_id
left outer join categories on bg_category = ct_id
left outer join priorities on bg_priority = pr_id
left outer join statuses on bg_status = st_id
left outer join users asg on bg_assigned_to_user = asg.us_id
left outer join users ru on bg_reported_user = ru.us_id
left outer join users lu on bg_last_updated_user = lu.us_id
left outer join bug_subscriptions on bs_bug = bg_id and bs_user = $this_usid
left outer join project_user_xref on pj_id = pu_project
	and pu_user = $this_usid
where bg_id = $id";

            if (ds_custom_cols.Tables[0].Rows.Count == 0)
            {
                sql = sql.Replace("$custom_cols_placeholder", "");
            }
            else
            {
                string custom_cols_sql = "";

                foreach (DataRow drcc in ds_custom_cols.Tables[0].Rows)
                {
                    custom_cols_sql += ",[" + drcc["name"].ToString() + "]";

                }
                sql = sql.Replace("$custom_cols_placeholder", custom_cols_sql);
            }

            sql = sql.Replace("$id", Convert.ToString(bugid));
            sql = sql.Replace("$this_usid", Convert.ToString(security.this_usid));
            sql = sql.Replace("$this_org", Convert.ToString(security.this_org));
            sql = sql.Replace("$dpl", Util.get_setting("DefaultPermissionLevel", "2"));

            DbUtil dbutil = new DbUtil();
            return dbutil.get_datarow(sql);


        }

        ///////////////////////////////////////////////////////////////////////
        public static DataSet get_bug_posts(int bugid)
        {
            string sql = @"select
				a.bp_bug,
				a.bp_comment,
				isnull(us_username,'') [us_username],
				case rtrim(us_firstname)
					when null then isnull(us_lastname, '')
					when '' then isnull(us_lastname, '')
					else isnull(us_lastname + ', ' + us_firstname,'')
				end [us_fullname],
				isnull(us_email,'') [us_email],
				a.bp_date,
				a.bp_id,
				a.bp_type,
				isnull(a.bp_email_from,'') bp_email_from,
				isnull(a.bp_email_to,'') bp_email_to,
				isnull(a.bp_file,'') bp_file,
				isnull(a.bp_size,0) bp_size,
				isnull(a.bp_content_type,'') bp_content_type,
				a.bp_hidden_from_external_users,
				isnull(ba.bp_file,'') ba_file,  -- intentionally ba
				isnull(ba.bp_id,'') ba_id, -- intentionally ba
				isnull(ba.bp_size,'') ba_size,  -- intentionally ba
				isnull(ba.bp_content_type,'') ba_content_type -- intentionally ba
				from bug_posts a
				left outer join users on us_id = a.bp_user
				left outer join bug_posts ba on ba.bp_parent = a.bp_id and ba.bp_bug = a.bp_bug
				where a.bp_bug = $id
				and a.bp_parent is null
				order by a.bp_date " + Util.get_setting("CommentSortOrder", "desc");

            sql = sql.Replace("$id", Convert.ToString(bugid));
            DbUtil dbutil = new DbUtil();
            return dbutil.get_dataset(sql);

        }

        ///////////////////////////////////////////////////////////////////////
        public static int get_bug_permission_level(int bugid, Security security)
        {
            /*
                    public const int PERMISSION_NONE = 0;
                    public const int PERMISSION_READONLY = 1;
                    public const int PERMISSION_REPORTER = 3;
                    public const int PERMISSION_ALL = 2;
            */

            // fetch the revised permission level
            string sql = @"
declare @bg_org int

select isnull(pu_permission_level,$dpl),
	bg_org
	from bugs
	left outer join project_user_xref
	on pu_project = bg_project
	and pu_user = $us
	where bg_id = $bg";
;

            sql = sql.Replace("$dpl", Util.get_setting("DefaultPermissionLevel", "2"));
            sql = sql.Replace("$bg", Convert.ToString(bugid));
            sql = sql.Replace("$us", Convert.ToString(security.this_usid));
            DbUtil dbutil = new DbUtil();
            DataRow dr = dbutil.get_datarow(sql);
            int pl = (int) dr[0];
            int bg_org = (int) dr[1];

            // reduce permissions for guest
            if (security.this_is_guest && pl == Security.PERMISSION_ALL)
            {
                pl = Security.PERMISSION_REPORTER;
            }

			// maybe reduce permissions
			if (bg_org != security.this_org)
			{
				if (security.this_other_orgs_permission_level == Security.PERMISSION_NONE
				|| security.this_other_orgs_permission_level == Security.PERMISSION_READONLY)
				{
					if (security.this_other_orgs_permission_level < pl)
					{
						pl = security.this_other_orgs_permission_level;
					}
				}
			}

            return pl;
        }


        public class NewIds
        {
            public NewIds(int b, int p)
            {
                bugid = b;
                postid = p;
            }
            public int bugid;
            public int postid;
        };

        ///////////////////////////////////////////////////////////////////////
        public static NewIds insert_bug(
            string short_desc,
            Security security,
            int projectid,
            int orgid,
            int categoryid,
            int priorityid,
            int statusid,
            int assigned_to_userid,
            int udfid,
            string project_custom_dropdown_value1,
            string project_custom_dropdown_value2,
            string project_custom_dropdown_value3,
            string comments,
            string from,
            string content_type,
            bool internal_only,
            System.Collections.Hashtable hash_custom_cols,
            bool send_notifications)
        {

            DbUtil dbutil = new DbUtil();

            if (assigned_to_userid == 0)
            {
                assigned_to_userid = btnet.Util.get_default_user(projectid);
            }

            string sql = @"insert into bugs
					(bg_short_desc,
					bg_reported_user,
					bg_last_updated_user,
					bg_reported_date,
					bg_last_updated_date,
					bg_project,
					bg_org,
					bg_category,
					bg_priority,
					bg_status,
					bg_assigned_to_user,
					bg_user_defined_attribute,
					bg_project_custom_dropdown_value1,
					bg_project_custom_dropdown_value2,
					bg_project_custom_dropdown_value3
					$custom_cols_placeholder1)
					values (N'$short_desc', $reported_user,  $reported_user, getdate(), getdate(),
					$project, $org,
					$category, $priority, $status, $assigned_user, $udf,
					N'$pcd1',N'$pcd2',N'$pcd3' $custom_cols_placeholder2)";

            sql = sql.Replace("$short_desc", short_desc.Replace("'", "''"));
            sql = sql.Replace("$reported_user", Convert.ToString(security.this_usid));
            sql = sql.Replace("$project", Convert.ToString(projectid));
            sql = sql.Replace("$org", Convert.ToString(orgid));
            sql = sql.Replace("$category", Convert.ToString(categoryid));
            sql = sql.Replace("$priority", Convert.ToString(priorityid));
            sql = sql.Replace("$status", Convert.ToString(statusid));
            sql = sql.Replace("$assigned_user", Convert.ToString(assigned_to_userid));
            sql = sql.Replace("$udf", Convert.ToString(udfid));
            sql = sql.Replace("$pcd1", project_custom_dropdown_value1);
            sql = sql.Replace("$pcd2", project_custom_dropdown_value2);
            sql = sql.Replace("$pcd3", project_custom_dropdown_value3);

            if (hash_custom_cols == null)
            {
                sql = sql.Replace("$custom_cols_placeholder1", "");
                sql = sql.Replace("$custom_cols_placeholder2", "");
            }
            else
            {

                string custom_cols_sql1 = "";
                string custom_cols_sql2 = "";

                // We need to know the datatype of the custom columns
                // so create a hash where we can look these up.
                System.Collections.Hashtable hash_custom_col_datatypes
                    = new System.Collections.Hashtable();

                DataSet ds_custom_cols = btnet.Util.get_custom_columns(dbutil);
                foreach (DataRow drcc in ds_custom_cols.Tables[0].Rows)
                {
                    hash_custom_col_datatypes.Add(
                        (string)drcc["name"],
                        (string)drcc["datatype"]);

                    //			Response.Write (drcc["name"]);
                    //			Response.Write (drcc["datatype"]);
                }


                System.Collections.IDictionaryEnumerator custom_col = hash_custom_cols.GetEnumerator();
                while (custom_col.MoveNext())
                {

                    custom_cols_sql1 += ",[" + custom_col.Key + "]";
                    string custom_col_val = custom_col.Value.ToString();

                    // look up datatype
                    if (hash_custom_col_datatypes[custom_col.Key].ToString() == "datetime")
                    {
                        custom_col_val = btnet.Util.format_local_date_into_db_format(custom_col_val);
                    }
                    if (custom_col_val.Length == 0)
                    {
                        custom_cols_sql2 += ", null";
                    }
                    else
                    {
                        custom_cols_sql2 += ",N'"
                            + custom_col_val.Replace("'", "''")
                            + "'";
                    }
                }
                sql = sql.Replace("$custom_cols_placeholder1", custom_cols_sql1);
                sql = sql.Replace("$custom_cols_placeholder2", custom_cols_sql2);
            }



            sql += "\nselect scope_identity()";


            int bugid = Convert.ToInt32(dbutil.execute_scalar(sql));
            int postid = btnet.Bug.insert_comment(bugid, security.this_usid, comments, from, content_type, internal_only);

            btnet.Bug.auto_subscribe(bugid);

            if (send_notifications)
            {
                btnet.Bug.send_notifications(btnet.Bug.INSERT, bugid, security);
            }

            return new NewIds(bugid, postid);

        }


        ///////////////////////////////////////////////////////////////////////
        public static int insert_comment(
			int bugid,
			int this_usid,
			string comments,
			string from,
			string content_type,
			bool internal_only)
        {

            if (comments != "")
            {
                string sql = @"
declare @now datetime
set @now = getdate()
insert into bug_posts
(bp_bug, bp_user, bp_date, bp_comment, bp_comment_search, bp_email_from, bp_type, bp_content_type,
bp_hidden_from_external_users)
values(
$id,
$us,
@now,
N'$comment',
N'$comment_search',
N'$from',
N'$type',
N'$content_type',
$internal)
select scope_identity();";

                string s = comments.Replace("'", "''");

                if (from != null)
                {
                    // Update the bugs timestamp here.
                    // We don't do it unconditionally because it would mess up the locking.
                    // The edit_bug.aspx page gets its snapshot timestamp from the update of the bug
                    // row, not the comment row, so updating the bug again would confuse it.
                    sql += @"update bugs
						set bg_last_updated_date = @now,
						bg_last_updated_user = $us
						where bg_id = $id";

                    sql = sql.Replace("$from", from.Replace("'","''"));
                    sql = sql.Replace("$type", "received"); // received email
                }
                else
                {
                    sql = sql.Replace("N'$from'", "null");
                    sql = sql.Replace("$type", "comment"); // bug comment
                }

                sql = sql.Replace("$id", Convert.ToString(bugid));
                sql = sql.Replace("$us", Convert.ToString(this_usid));
                sql = sql.Replace("$comment", s);
                sql = sql.Replace("$comment_search", s);
                sql = sql.Replace("$content_type", content_type);
              	sql = sql.Replace("$internal", btnet.Util.bool_to_string(internal_only));


                DbUtil dbutil = new DbUtil();
                return Convert.ToInt32(dbutil.execute_scalar(sql));

            }
            else
            {
                return 0;
            }

        }

        ///////////////////////////////////////////////////////////////////////
        public static string send_notifications(int insert_or_update, int bugid, Security security, int just_to_this)
        {
            return send_notifications(insert_or_update,
                bugid,
                security,
                just_to_this,
                false,  // status changed
                false,  // assigend to changed
                0);  // prev assigned to
        }

        ///////////////////////////////////////////////////////////////////////
        public static string send_notifications(int insert_or_update, int bugid, Security security)
        {
            return send_notifications(insert_or_update,
                bugid,
                security,
                0,  // just to this
                false,  // status changed
                false,  // assigend to changed
                0);  // prev assigned to
        }


        ///////////////////////////////////////////////////////////////////////
        public static string send_notifications(int insert_or_update,
            int bugid,
            Security security,
            int just_to_this_userid,
            bool status_changed,
            bool assigned_to_changed,
            int prev_assigned_to_user)
        {

            string result = "";

            bool notification_email_enabled = (btnet.Util.get_setting("NotificationEmailEnabled", "1") == "1");

            if (notification_email_enabled)
            {
                // MAW -- 2006/01/27 -- Determine level of change detected
                int changeLevel = 0;
                if (insert_or_update == INSERT)
                {
                    changeLevel = 1;
                }
                else if (status_changed)
                {
                    changeLevel = 2;
                }
                else if (assigned_to_changed)
                {
                    changeLevel = 3;
                }
                else
                {
                    changeLevel = 4;
                }

                string sql;

                if (just_to_this_userid > 0)
                {
                    sql = @"
/* get notification email for just one user  */
select us_email
from bug_subscriptions
inner join users on bs_user = us_id
inner join orgs on us_org = og_id
inner join bugs on bg_id = bs_bug
left outer join project_user_xref on pu_user = us_id and pu_project = bg_project
where us_email is not null
and us_enable_notifications = 1
-- $status_change
and us_active = 1
and us_email <> ''
and
	case
		when
			us_org <> bg_org
			and og_other_orgs_permission_level < 2
			and og_other_orgs_permission_level < isnull(pu_permission_level,$dpl)
				then og_other_orgs_permission_level
		else
			isnull(pu_permission_level,$dpl)
	end <> 0
and bs_bug = $id
and us_id = $just_this_usid";

                    sql = sql.Replace("$just_this_usid", Convert.ToString(just_to_this_userid));
                }
                else
                {

                    // MAW -- 2006/01/27 -- Added different notifications if reported or assigned-to
                    sql = @"
/* get notification emails for all subscribers */
select us_email
from bug_subscriptions
inner join users on bs_user = us_id
inner join orgs on us_org = og_id
inner join bugs on bg_id = bs_bug
left outer join project_user_xref on pu_user = us_id and pu_project = bg_project
where us_email is not null
and us_enable_notifications = 1
-- $status_change
and us_active = 1
and us_email <> ''
and (   ($cl <= us_reported_notifications and bg_reported_user = bs_user)
or ($cl <= us_assigned_notifications and bg_assigned_to_user = bs_user)
or ($cl <= us_assigned_notifications and $pau = bs_user)
or ($cl <= us_subscribed_notifications))
and
case
	when
		us_org <> bg_org
		and og_other_orgs_permission_level < 2
		and og_other_orgs_permission_level < isnull(pu_permission_level,$dpl)
			then og_other_orgs_permission_level
	else
		isnull(pu_permission_level,$dpl)
end <> 0
and bs_bug = $id
and (us_id <> $us or isnull(us_send_notifications_to_self,0) = 1)";
                }

                sql = sql.Replace("$cl", changeLevel.ToString());
                sql = sql.Replace("$pau", prev_assigned_to_user.ToString());
                sql = sql.Replace("$id", Convert.ToString(bugid));
                sql = sql.Replace("$dpl", btnet.Util.get_setting("DefaultPermissionLevel", "2"));
                sql = sql.Replace("$us", Convert.ToString(security.this_usid));

                DbUtil dbutil = new DbUtil();
                DataSet subscribers = dbutil.get_dataset(sql);

                if (subscribers.Tables[0].Rows.Count > 0)
                {

                    // Get bug html
                    DataRow bug_dr = btnet.Bug.get_bug_datarow(bugid, security);

                    // Create a fake response and let the code
                    // write the html to that response
                    System.IO.StringWriter writer = new System.IO.StringWriter();
                    HttpResponse my_response = new HttpResponse(writer);
					my_response.Write("<html>");
					my_response.Write("<head>");
					my_response.Write("<base href=\"" +
					btnet.Util.get_setting("AbsoluteUrlPrefix","http://127.0.0.1/") + "\"/>");
					my_response.Write("</head>");

                    PrintBug.print_bug(my_response, bug_dr, security.this_is_admin, true /* external_user */);
                    // at this point "writer" has the bug html


                    string from = btnet.Util.get_setting("NotificationEmailFrom", "");
                    string subject = btnet.Util.get_setting("NotificationSubjectFormat", "$THING$:$BUGID$ was $ACTION$ - $SHORTDESC$ $TRACKINGID$");

                    subject = subject.Replace("$THING$", btnet.Util.capitalize_first_letter(btnet.Util.get_setting("SingularBugLabel", "bug")));

                    string action = "";
                    if (insert_or_update == INSERT)
                    {
                        action = "added";
                    }
                    else
                    {
                        action = "updated";
                    }

                    subject = subject.Replace("$ACTION$", action);
                    subject = subject.Replace("$BUGID$", Convert.ToString(bugid));
                    subject = subject.Replace("$SHORTDESC$", (string)bug_dr["short_desc"]);

                    string tracking_id = " (";
                    tracking_id += btnet.Util.get_setting("TrackingIdString", "DO NOT EDIT THIS:");
                    tracking_id += Convert.ToString(bugid);
                    tracking_id += ")";
                    subject = subject.Replace("$TRACKINGID$", tracking_id);

                    subject = subject.Replace("$PROJECT$", (string)bug_dr["current_project"]);
                    subject = subject.Replace("$ORGANIZATION$", (string)bug_dr["og_name"]);
                    subject = subject.Replace("$CATEGORY$", (string)bug_dr["category_name"]);
                    subject = subject.Replace("$PRIORITY$", (string)bug_dr["priority_name"]);
                    subject = subject.Replace("$STATUS$", (string)bug_dr["status_name"]);
                    subject = subject.Replace("$ASSIGNED_TO$", (string)bug_dr["assigned_to_username"]);



                    string to = "";

                    if (btnet.Util.get_setting("SendJustOneEmail", "1") == "1")
                    {

                        // send just one email, with a bunch of addresses

                        foreach (DataRow dr in subscribers.Tables[0].Rows)
                        {
                            // Concat in a string for performance
                            to += (string)dr["us_email"] + ";";
                        }

                        result += btnet.Email.send_email( // 6 args
                            to,
                            from,
                            "", // cc
                            subject,
                            writer.ToString(),
                            System.Web.Mail.MailFormat.Html);

                    }
                    else
                    {

                        // send a separate email to each subscriber
                        foreach (DataRow dr in subscribers.Tables[0].Rows)
                        {
                            to = (string)dr["us_email"];

                            result += btnet.Email.send_email(  // 5 args
                                to,
                                from,
                                "", // cc
                                subject, writer.ToString(),
                                System.Web.Mail.MailFormat.Html);
                        }

                    }
                }
            }

            return result;
        }




    } // end Bug

}
