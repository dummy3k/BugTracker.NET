<%@ Page language="C#"  validateRequest="false"%>
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

		if (security.user.is_admin || security.user.can_edit_sql)
		{
			// these guys can do everything
			vis_everybody.Checked = true;

			sql = @"/* populate org dropdown */
				select og_id, og_name
				from orgs
				order by og_name;";

			DataSet ds_orgs = dbutil.get_dataset(sql);

			// forced project dropdown
			org.DataSource = ds_orgs.Tables[0].DefaultView;
			org.DataTextField = "og_name";
			org.DataValueField = "og_id";
			org.DataBind();
			org.Items.Insert(0, new ListItem("[select org]", "0"));

		}
		else
		{
			sql_text.Visible = false;
			sql_text_label.Visible = false;
			explanation.Visible = false;

			vis_everybody.Enabled = false;
			vis_org.Enabled = false;
			vis_user.Checked = true;
			org.Enabled = false;

			org.Visible = false;
			vis_everybody.Visible = false;
			vis_org.Visible = false;
			vis_user.Visible = false;
			visibility_label.Visible = false;

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
				qu_desc, qu_sql, isnull(qu_user,0) [qu_user], isnull(qu_org,0) [qu_org]
				from queries where qu_id = $1";


			sql = sql.Replace("$1", Convert.ToString(id));
			DataRow dr = dbutil.get_datarow(sql);

			if ((int) dr["qu_user"] != security.user.usid)
			{
				if (security.user.is_admin || security.user.can_edit_sql)
				{
					// these guys can do everything
				}
				else
				{
					Response.Write ("You are not allowed to edit this query");
					Response.End();
				}
			}

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

			if ((int) dr["qu_user"] == 0 && (int) dr["qu_org"] == 0)
			{
				vis_everybody.Checked = true;
			}
			else if ((int) dr["qu_user"] == security.user.usid)
			{
				vis_user.Checked = true;
			}
			else
			{
				vis_org.Checked = true;
				foreach (ListItem li in org.Items)
				{
					if (Convert.ToInt32(li.Value) == (int) dr["qu_org"])
					{
						li.Selected = true;
						break;
					}
				}
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


	if (vis_org.Checked)
	{
		if (org.SelectedIndex < 1)
		{
			good = false;
			org_err.InnerText = "You must select a org.";
		}
		else
		{
			org_err.InnerText = "";
		}
	}
	else
	{
		org_err.InnerText = "";
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
				(qu_desc, qu_sql, qu_default, qu_user, qu_org)
				values (N'$de', N'$sq', 0, $us, $rl)";
		}
		else // edit existing
		{

			sql = @"update queries set
				qu_desc = N'$de',
				qu_sql = N'$sq',
				qu_user = $us,
				qu_org = $rl
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

		if (vis_everybody.Checked)
		{
			sql = sql.Replace("$us", "0");
			sql = sql.Replace("$rl", "0");
		}
		else if (vis_user.Checked)
		{
			sql = sql.Replace("$us", Convert.ToString(security.user.usid));
			sql = sql.Replace("$rl", "0");
		}
		else
		{
			sql = sql.Replace("$rl", Convert.ToString(org.SelectedItem.Value));
			sql = sql.Replace("$us", "0");
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
	<table border=0 cellspacing=8 cellpadding=0>

	<tr>
	<td class=lbl>Description:</td>
	<td><input runat="server" type=text class=txt id="desc" maxlength=80 size=80></td>
	<td runat="server" class=err id="desc_err">&nbsp;</td>
	</tr>

	<tr>
	<td class=lbl runat="server" id="visibility_label">Visibility:</td>
	<td colspan=2>
		<asp:RadioButton text="Everybody" runat="server" GroupName="visibility" id="vis_everybody"/>
		&nbsp;&nbsp;&nbsp;
		<asp:RadioButton text="Just You" runat="server" GroupName="visibility" id="vis_user"/>
		&nbsp;&nbsp;&nbsp;
		<asp:RadioButton text="Users with org" runat="server" GroupName="visibility" id="vis_org"/>
		<asp:DropDownList id="org" runat="server">
		</asp:DropDownList>
		&nbsp;&nbsp;
		<span runat="server" class=err id="org_err">&nbsp;</span>
	</td>

	<tr>
	<td colspan=3>
	<span class=lbl id="sql_text_label" runat="server">SQL:</span><br>
	<textarea rows=24 cols=100 runat="server" class=txt name="sql_text" id="sql_text"></textarea></td>


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
	<td id="explanation" colspan=3 class=cmt runat="server">
		In order to work with the bugs.aspx page, your SQL must be structured in a particular way.
		<br><br>
		The first column must be either a color starting with "#" or a CSS style class. If it does not start with "#" it will be interpreted as a CSS style class.
		<br>
		<br>
		View <a target="_blank" href="edit_styles.aspx">example</a> on how to use priority and/or status
		to determine the CSS style.
		<br>
		<br>
		The second column must be "bg_id".
		<br><br>
		You can use the magic word "$ME" in your query which will be replaced by your user ID.
		<br>
		For example:
		<br>
		<ul>
			select isnull(pr_background_color,'#ffffff'), bg_id [id], bg_short_desc<br>
			from bugs<br>
			left outer join priorities on bg_priority = pr_id<br>
			where bg_assigned_to_user = $ME
		</ul>
		<br>
		Another magic word is "$FLAG", which is what controls whether a query shows the "!" column that lets an individual user flag items for himself.<br>
		To use it, add the SQL shown below to your select columns and do a "left outer join" to the bug_user_flags table.
		<ul>
			Select ...., isnull(fl_flag,0) [$FLAG],...<br>
			from bugs<br>
			left outer join bug_user_flags on fl_bug = bg_id and fl_user = $ME
		</ul>
	</td>
	</tr>

	</table>
	<p>
</form>
</td></tr></table>
<% Response.Write(Application["custom_footer"]); %></body>
</html>


