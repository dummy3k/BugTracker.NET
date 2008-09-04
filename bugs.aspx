<%@ Page language="C#"%>
<!--
Copyright 2002-2008 Corey Trager
Distributed under the terms of the GNU General Public License
-->
<!-- #include file = "inc.aspx" -->

<script language="C#" runat="server">

DbUtil dbutil;
Security security;
string qu_id_string = null;
string sql_error = "";

///////////////////////////////////////////////////////////////////////
void Page_Load(Object sender, EventArgs e)
{

	Util.do_not_cache(Response);
	dbutil = new DbUtil();
	security = new Security();
	security.check_security(dbutil, HttpContext.Current, Security.ANY_USER_OK);

	titl.InnerText = Util.get_setting("AppTitle","BugTracker.NET") + " - "
		+ Util.get_setting("PluralBugLabel","bugs");


	if (!IsPostBack) {

		load_query_dropdown();

		do_query();

	}
	else {

		// posting back a query change?
		// posting back a filter change?
		// posting back a sort change?

		if (actn.Value == "query")
		{
			qu_id_string = Convert.ToString(query.SelectedItem.Value);
			reset_query_state();
			do_query();
		}
		else
		{
			// sorting, paging, filtering, so don't go back to the database

			dv = (DataView) Session["bugs"];
			if (dv == null)
			{
				do_query();
			}
			else
			{
				if (actn.Value == "sort")
				{
					new_page.Value = "0";
				}
			}
		}
	}

	select_query_in_dropdown();
	sort_and_filter_dataview(); // reuse sorts, filters
	actn.Value = "";
}


///////////////////////////////////////////////////////////////////////
void select_query_in_dropdown()
{

	// select drop down based on whatever query we ended up using
	if (qu_id_string != null)
	{
		foreach (ListItem li in query.Items)
		{
			if (li.Value == qu_id_string)
			{
				li.Selected = true;
				break;
			}
		}
	}

}

///////////////////////////////////////////////////////////////////////
void reset_query_state()
{
	new_page.Value = "0";
	filter.Value = "";
	sort.Value = "-1";
	prev_sort.Value = "-1";
	prev_dir.Value ="ASC";
}


///////////////////////////////////////////////////////////////////////
void do_query()
{
	// figure out what SQL to run and run it.

	string bug_sql = null;


	// From the URL
	if (qu_id_string == null)
	{
		// specified in URL?
		qu_id_string = Request["qu_id"];
	}

	// From a previous viewing of this page
	if (qu_id_string == null)
	{
		// Is there a previously selected query, from a use of this page
		// earlier in this session?
		qu_id_string = (string) Session["SelectedBugQuery"];
	}


	if (qu_id_string != null && qu_id_string != "" && qu_id_string != "0")
	{
		// Use sql specified in query string.
		// This is the normal path from the queries page.
		sql = @"select qu_sql from queries where qu_id = $quid";
		sql = sql.Replace("$quid", qu_id_string);
		bug_sql = (string)dbutil.execute_scalar(sql);
	}

	if (bug_sql == null)
	{
		// This is the normal path after logging in.
		// Use sql associated with user
		sql = @"select qu_id, qu_sql from queries where qu_id in
			(select us_default_query from users where us_id = $us)";
		sql = sql.Replace("$us", Convert.ToString(security.user.usid));
		DataRow dr = dbutil.get_datarow(sql);
		if (dr != null)
		{
			qu_id_string = Convert.ToString(dr["qu_id"]);
			bug_sql = (string)dr["qu_sql"];
		}
	}

	// As a last resort, grab some query.
	if (bug_sql == null)
	{
		sql = @"select top 1 qu_id, qu_sql from queries order by case when qu_default = 1 then 1 else 0 end desc";
		DataRow dr = dbutil.get_datarow(sql);
		bug_sql = (string) dr["qu_sql"];
		if (dr != null)
		{
			qu_id_string = Convert.ToString(dr["qu_id"]);
			bug_sql = (string)dr["qu_sql"];
		}
	}

	if (bug_sql == null)
	{
		Response.Write ("Error!. No queries available for you to use!<p>Please contact your BugTracker.NET administrator.");
		Response.End();
	}

	// Whatever query we used, select it in the drop down
	if (qu_id_string != null)
	{
		foreach (ListItem li in query.Items)
		{
			li.Selected = false;
		}
		foreach (ListItem li in query.Items)
		{
			if (li.Value == qu_id_string)
			{
				li.Selected = true;
				break;
			}
		}
	}


	// replace magic variables
	bug_sql = bug_sql.Replace("$ME", Convert.ToString(security.user.usid));

	bug_sql = Util.alter_sql_per_project_permissions(bug_sql,security);

	if (Util.get_setting("UseFullNames","0") == "0")
	{
		// false condition
		bug_sql = bug_sql.Replace("$fullnames","0 = 1");
	}
	else
	{
		// true condition
		bug_sql = bug_sql.Replace("$fullnames","1 = 1");
	}

	// run the query
	DataSet ds = null;
	try
	{
		ds = dbutil.get_dataset (bug_sql);
		dv = new DataView(ds.Tables[0]);
	}
	catch(System.Data.SqlClient.SqlException e)
	{
		sql_error = e.Message;
		dv = null;
	}


	// Save it.
	Session["bugs"] = dv;
	Session["SelectedBugQuery"] = qu_id_string;

	// Save it again.  We use the unfiltered query to determine the
	// values that go in the filter dropdowns.
	if (ds != null)
	{
		Session["bugs_unfiltered"] = ds.Tables[0];
	}
	else
	{
		Session["bugs_unfiltered"] = null;
	}

}

///////////////////////////////////////////////////////////////////////
void load_query_dropdown()
{

	// populate query drop down
	sql = @"declare @us_org int
		select @us_org = us_org from users where us_id = $us

		select qu_id, qu_desc
		from queries
		where (isnull(qu_user,0) = 0 and isnull(qu_org,0) = 0)
		or isnull(qu_user,0) = $us
		or isnull(qu_org,0) = @us_org
		order by qu_desc";

	sql = sql.Replace("$us",Convert.ToString(security.user.usid));

	query.DataSource = dbutil.get_dataview(sql);

	query.DataTextField = "qu_desc";
	query.DataValueField = "qu_id";
	query.DataBind();

}



</script>

<!-- #include file = "inc_bugs.inc" -->

<html>
<head>
<title id="titl" runat="server">btnet bugs</title>
<link rel="StyleSheet" href="btnet.css" type="text/css">
<script type="text/javascript" language="JavaScript" src="bug_list.js"></script>

<script>

function get_or_post()
{
	// set the main form's method to either GET or POST.
	var frm =  document.getElementById('<% Response.Write(Util.get_form_name()); %>');
	frm.method = '<% Response.Write(Util.get_setting("BugListFormSubmitMethod","POST")); %>';
}

function on_query_changed() {
	var frm = document.getElementById(asp_form_id);
	frm.actn.value = "query";
	frm.submit();
}


</script>

</head>
<body onload="get_or_post()">
<% security.write_menu(Response, Util.get_setting("PluralBugLabel","bugs")); %>

<div id="popup" class="buglist_popup"></div>

<form method="get" runat="server">

<div class=align>

<table border=0><tr>
	<td  nowrap>
	<% if (!security.user.adds_not_allowed) { %>
	<a href=edit_bug.aspx>add new <% Response.Write(Util.get_setting("SingularBugLabel","bug")); %></a>
	&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
	<% } %>

	<td  nowrap>
	<asp:DropDownList id="query" runat="server" onchange="on_query_changed()">
	</asp:DropDownList>

	<td nowrap>
	&nbsp;&nbsp;&nbsp;&nbsp;<a target=_blank href=print_bugs.aspx>print list</a>
	<td  nowrap>
	&nbsp;&nbsp;&nbsp;&nbsp;<a target=_blank href=print_bugs2.aspx>print detail</a>
	<td  nowrap>
	&nbsp;&nbsp;&nbsp;&nbsp;<a target=_blank href=print_bugs.aspx?format=excel>export to excel</a>
	<td  nowrap align=right width=100%>
	<a target=_blank href=screen_capture.html>screen capture</a>
</table>

<script>

function show_tags()
{
	popup_window = window.open(
		'tags.aspx',
		'tags',
		"menubar=0,scrollbars=1,toolbar=0,resizable=1,width=300,height=400")

	popup_window.focus()

}

function append_tag(s)
{
	el = document.getElementById("tags")
	if (el.value != "")
	{
		el.value += ","
	}

	el.value += s;
}

function done_selecting_tags()
{
	on_filter()
}

</script>

<p>
<%
if (dv != null)
{
	if (dv.Table.Rows.Count > 0)
	{

		if (btnet.Util.get_setting("EnableTags","0") == "1")
		{
			Response.Write("<p>show only with <a href='javascript:show_tags()'>tags</a>:&nbsp;");
			Response.Write("<input name=tags id=tags onchange='javascript:on_filter()' value='");
			Response.Write(Request["tags"]);
			Response.Write("'>");
			//Response.Write("<a href='javascript:on_filter()'>go</a>");
			Response.Write("<br>");
		}


		display_bugs();
	}
	else
	{
		Response.Write ("<p>No ");
		Response.Write (Util.get_setting("PluralBugLabel","bugs"));
		Response.Write (" yet.<p>");
	}
}
else
{
	Response.Write ("<div class=err>Error in query SQL: " + sql_error + "</div>");
}
%>
<!-- #include file = "inc_bugs2.inc" -->
</div>
</form>
<% Response.Write(Application["custom_footer"]); %></body>
</html>

