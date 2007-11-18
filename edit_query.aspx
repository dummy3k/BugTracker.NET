<%@ Page language="C#"  validateRequest="false"%>
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

	security.check_security(dbutil, HttpContext.Current, Security.ANY_USER_OK);

	titl.InnerText = Util.get_setting("AppTitle","BugTracker.NET") + " - "
		+ "edit query";

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

		if (security.this_is_admin || security.this_can_edit_sql)
		{
			// these guys can do everything
			public_query.Checked = true;
		}
		else
		{
			sql_text.Visible = false;
			sql_text_label.Visible = false;
			explanation.Visible = false;

			public_query.Enabled = false;
			private_query.Checked = true;

			default_query.Visible = false;
			default_query.Checked = false;
			default_query_label.Visible = false;
			default_query_note.Visible = false;
		}


		// add or edit?
		if (id == 0)
		{
			sub.Value = "Create";
			sql_text.Value = HttpUtility.HtmlDecode(Request.Form["sql_text"]); // if coming from search.aspx

		}
		else
		{


			sub.Value = "Update";

			// Get this entry's data from the db and fill in the form

			sql = @"select
				qu_desc, qu_sql, isnull(qu_user,0) [qu_user], qu_default
				from queries where qu_id = $1";


			sql = sql.Replace("$1", Convert.ToString(id));
			DataRow dr = dbutil.get_datarow(sql);

			// Fill in this form
			desc.Value = (string) dr["qu_desc"];

			if (Util.get_setting("HtmlEncodeSql","0") == "1")
			{
				sql_text.Value = Server.HtmlEncode((string) dr["qu_sql"]);
			}
			else
			{
				sql_text.Value = (string) dr["qu_sql"];
			}
			default_query.Checked = Convert.ToBoolean((int) dr["qu_default"]);

			if ((int) dr["qu_user"] != security.this_usid)
			{
				if (security.this_is_admin || security.this_can_edit_sql)
				{
					// these guys can do everything
				}
				else
				{
					Response.Write ("You are not allowed to edit this item");
					Response.End();
				}

				public_query.Checked = true;
			}
			else
			{
				private_query.Checked = true;
			}

		}
	}

}



///////////////////////////////////////////////////////////////////////
Boolean validate()
{

	Boolean good = true;

	if (desc.Value == "")
	{
		good = false;
		desc_err.InnerText = "Description is required.";
	}
	else
	{
		desc_err.InnerText = "";
	}


	default_err.InnerText = "";
	if (default_query.Checked)
	{
		if (public_query.Checked)
		{

			if (id == 0)
			{
				sql = @"select count(1) from queries where qu_default = 1 and isnull(qu_user,0) = 0";
			}
			else
			{
				sql = @"select count(1) from queries where qu_default = 1 and isnull(qu_user,0) = 0 and qu_id <> $id";
				sql = sql.Replace("$id",Convert.ToString(id));
			}

			int number_of_default_queries = (int) dbutil.execute_scalar(sql);

			if (number_of_default_queries != 0)
			{
				default_err.InnerText = "There already is a public default query.  There can be ony one.";
				good = false;
			}

		}
		else
		{
			default_err.InnerText = "A private query cannot be a default query.";
			good = false;
		}
	}


	if (id == 0)
	{
		// See if name is already used?
		sql = "select count(1) from queries where qu_desc = N'$de'";
		sql = sql.Replace("$de", desc.Value.Replace("'","''"));
		int query_count = (int) dbutil.execute_scalar(sql);

		if (query_count == 1)
		{
			desc_err.InnerText = "A query with this name already exists.   Choose another name.";
			msg.InnerText = "Query was not created.";
			good = false;
		}
	}
	else
	{
		// See if name is already used?
		sql = "select count(1) from queries where qu_desc = N'$de' and qu_id <> $id";
		sql = sql.Replace("$de", desc.Value.Replace("'","''"));
		sql = sql.Replace("$id", Convert.ToString(id));
		int query_count = (int) dbutil.execute_scalar(sql);

		if (query_count == 1)
		{
			desc_err.InnerText = "A query with this name already exists.   Choose another name.";
			msg.InnerText = "Query was not created.";
			good = false;
		}
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
			sql = @"insert into queries
				(qu_desc, qu_sql, qu_default, qu_user)
				values (N'$de', N'$sq', $df, $us)";
		}
		else // edit existing
		{

			sql = @"update queries set
				qu_desc = N'$de',
				qu_sql = N'$sq',
				qu_default = $df,
				qu_user = $us
				where qu_id = $id";

			sql = sql.Replace("$id", Convert.ToString(id));

		}
		sql = sql.Replace("$de", desc.Value.Replace("'","''"));
		if (Util.get_setting("HtmlEncodeSql","0") == "1")
		{
			sql = sql.Replace("$sq", Server.HtmlDecode(sql_text.Value.Replace("'","''")));
		}
		else
		{
			sql = sql.Replace("$sq", sql_text.Value.Replace("'","''"));
		}
		sql = sql.Replace("$df", Util.bool_to_string(default_query.Checked));

		if (public_query.Checked)
		{
			sql = sql.Replace("$us", "0");
		}
		else
		{
			sql = sql.Replace("$us", Convert.ToString(security.this_usid));
		}

		dbutil.execute_nonquery(sql);
		Server.Transfer ("queries.aspx");

	}
	else
	{
		if (id == 0)  // insert new
		{
			msg.InnerText = "Query was not created.";
		}
		else // edit existing
		{
			msg.InnerText = "Query was not updated.";
		}

	}

}

</script>

<html>
<head>
<title id="titl" runat="server">btnet edit query</title>
<link rel="StyleSheet" href="btnet.css" type="text/css">
</head>
<body>
<% security.write_menu(Response, "queries"); %>

<div class=align><table border=0><tr><td>
<a href=queries.aspx>back to queries</a>
<form class=frm runat="server">
	<table border=0>

	<tr>
	<td class=lbl>Description:</td>
	<td><input runat="server" type=text class=txt id="desc" maxlength=80 size=80></td>
	<td runat="server" class=err id="desc_err">&nbsp;</td>
	</tr>

	<tr>
	<td class=lbl>Visibility:</td>
	<td>
		<asp:RadioButton text="Public" runat="server" class=txt GroupName="visibility" id="public_query"/>
		&nbsp;&nbsp;&nbsp;
		<asp:RadioButton text="Private" runat="server" class=txt GroupName="visibility" id="private_query"/>
		&nbsp;&nbsp;&nbsp;
		<span class=smallnote>Public = visibile to everybody.&nbsp;&nbsp;Private = visible just to you..</span>
	</td>
	<td runat="server" class=err id="public_err">&nbsp;</td>
	</tr>

	<tr>
	<td class=lbl id="default_query_label" runat="server">Default:</td>
	<td><asp:checkbox runat="server" class=txt id="default_query"/>
	&nbsp;&nbsp;&nbsp;<span class="smallnote" runat="server" id="default_query_note">Only used if no user setting specified</span>
	</td>
	<td><span runat="server" class=err id="default_err"></span></td>
	</tr>

	<tr>
	<td class=lbl id="sql_text_label" runat="server">SQL:</td>
	<td colspan=2><textarea rows=16 cols=85 runat="server" class=txt name="sql_text" id="sql_text"></textarea></td>


	<tr><td colspan=3 align=center>
	<span runat="server" class=err id="msg">&nbsp;</span>
	</td></tr>

	<tr>
	<td colspan=2 align=center>
	<input runat="server" class=btn type=submit id="sub" value="Create or Edit" OnServerClick="on_update">
	<td>&nbsp</td>
	</td>
	</tr>

	<tr>
	<td>&nbsp</td>
	<td colspan=2 class=cmt>
		<span id="explanation" runat="server">
			In order to work with the bugs.aspx page, your SQL must be structured in a particular way.
			<br><br>
			The first column must be a color starting with "#" or it will be interpreted as a CSS style class.
			<br>
			Write your query so as to get your background color from the priority's background color<br>
			or your CSS style class from either the priority or status.   See the admin pages.
			<br>
			<br>
			The second column must be "bg_id".
			<br>
			You can use the pseudo-variable $ME in your query which will be replaced by your user ID.
			<br>
			For example:
			<br>
			<ul>
				select isnull(pr_background_color,'#ffffff'), bg_id [id], bg_short_desc<br>
				from bugs
				<br>
				left outer join priorities on bg_priority = pr_id
				<br>
				where bg_assigned_to_user = $ME
			</ul>
		</span>
	</td>
	</tr>

	</table>
</form>
</td></tr></table>
<% Response.Write(Application["custom_footer"]); %></body>
</html>


