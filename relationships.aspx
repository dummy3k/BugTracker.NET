<%@ Page language="C#"%>
<!--
Copyright 2002-2007 Corey Trager
Distributed under the terms of the GNU General Public License
-->
<!-- #include file = "inc.aspx" -->

<script language="C#" runat="server">

int bugid;
DataSet ds;
DbUtil dbutil;
Security security;
int permission_level;

void Page_Load(Object sender, EventArgs e)
{

	Util.do_not_cache(Response);
	dbutil = new DbUtil();
	security = new Security();
	security.check_security(dbutil, HttpContext.Current, Security.ANY_USER_OK);
	string sql;
	add_err.InnerText = "";

	bugid = Convert.ToInt32(Util.sanitize_integer(Request["id"]));
	int bugid2 = 0;

	permission_level = Bug.get_bug_permission_level(bugid, security);
	if (permission_level == Security.PERMISSION_NONE)
	{
		Response.Write("You are not allowed to view this item");
		Response.End();
	}

	string action = Request["action"];

	if (action == null)
	{
		action = "";
	}

	if (action != "")
	{
		if (permission_level == Security.PERMISSION_READONLY)
		{
			Response.Write("You are not allowed to edit this item");
			Response.End();
		}

		if (action == "remove") // remove
		{
			if (Request["bugid2"] != null)
			{
				if (Util.is_int(Request["bugid2"]))
				{
					bugid2 = Convert.ToInt32((Request["bugid2"]));

					sql = @"
						delete from bug_relationships where re_bug2 = $bg2 and re_bug1 = $bg;
						delete from bug_relationships where re_bug1 = $bg2 and re_bug2 = $bg;
						insert into bug_posts
								(bp_bug, bp_user, bp_date, bp_comment, bp_type)
								values($bg, $us, getdate(), N'deleted relationship to $bg2', 'update')";
					sql = sql.Replace("$bg2",Convert.ToString(bugid2));
					sql = sql.Replace("$bg",Convert.ToString(bugid));
					sql = sql.Replace("$us",Convert.ToString(security.this_usid));
					dbutil.execute_nonquery(sql);
				}
			}
		}
		else
		{

			// adding

			if (Request["bugid2"] != null)
			{
				if (!Util.is_int(Request["bugid2"]))
				{
					add_err.InnerText = "Related ID must be an integer.";
				}
				else
				{
					bugid2 = Convert.ToInt32((Request["bugid2"]));

					if (bugid == bugid2)
					{
						add_err.InnerText = "Cannot create a relationship to self.";
					}
					else
					{
						int rows = 0;

						// check if bug exists
						sql = @"select count(1) from bugs where bg_id = $bg2";
						sql = sql.Replace("$bg2",Convert.ToString(bugid2));
						rows = (int) dbutil.execute_scalar(sql);

						if (rows == 0)
						{
							add_err.InnerText = "Not found.";
						}
						else
						{
							// check if relationship exists
							sql = @"select count(1) from bug_relationships where re_bug1 = $bg and re_bug2 = $bg2";
							sql = sql.Replace("$bg2",Convert.ToString(bugid2));
							sql = sql.Replace("$bg",Convert.ToString(bugid));
							rows = (int) dbutil.execute_scalar(sql);

							if (rows > 0)
							{
								add_err.InnerText = "Relationship already exists.";
							}
							else
							{
								// check permission of related bug
								int permission_level2 = Bug.get_bug_permission_level(bugid2, security);
								if (permission_level2 == Security.PERMISSION_NONE)
								{
									add_err.InnerText = "You are not allowed to view the related item.";
								}
								else
								{

									// insert the relationship both ways
									sql = @"
										insert into bug_relationships (re_bug1, re_bug2, re_type) values($bg, $bg2, N'$ty');
										insert into bug_posts
												(bp_bug, bp_user, bp_date, bp_comment, bp_type)
												values($bg, $us, getdate(), N'added relationship to $bg2', 'update');";

									//if (Request["two_way"] != null && Request["two_way"] != "")
									{
										sql += "insert into bug_relationships (re_bug2, re_bug1, re_type) values($bg, $bg2, N'$ty')";
									}
									sql = sql.Replace("$bg2",Convert.ToString(bugid2));
									sql = sql.Replace("$bg",Convert.ToString(bugid));
									sql = sql.Replace("$us",Convert.ToString(security.this_usid));
									sql = sql.Replace("$ty",Request["type"].Replace("'","''"));
									dbutil.execute_nonquery(sql);
									add_err.InnerText = "Relationship was added.";
								}
							}
						}
					}
				}
			}
		}

		//.Transfer ("relationships.aspx?id=" + Convert.ToString(bugid));
	}

	sql = @"select bg_id [id],
		bg_short_desc [desc ],
		re_type [comment],
		'<a target=_blank href=edit_bug.aspx?id=' + convert(varchar,bg_id) + '>view</a>' [view],
		'<a href=relationships.aspx?action=remove&id=$bg'
		+ '&bugid2='
		+ convert(varchar,re_bug2)
		+ '>detach</a>' [detach]
		from bugs
		inner join bug_relationships on bg_id = re_bug2
		where re_bug1 = $bg
		order by bg_id desc";

	sql = sql.Replace("$bg", Convert.ToString(bugid));
	sql = Util.alter_sql_per_project_permissions(sql, security.this_usid);

	ds = dbutil.get_dataset(sql);

}


</script>

<html>
<head>
<title id="titl" runat="server">btnet related <% Response.Write(Util.get_setting("PluralBugLabel","bugs"));%></title>
<link rel="StyleSheet" href="btnet.css" type="text/css">
<script type="text/javascript" language="JavaScript" src="sortable.js"></script>
</head>

<body onload=parent.set_relationship_cnt(<%Response.Write(Convert.ToString(ds.Tables[0].Rows.Count));%>)>
<div class=align>
Relationships
<p>
<table border=0><tr><td>

<%
if (permission_level != Security.PERMISSION_READONLY)
{
%>
<p>
<form class=frm action="relationships.aspx">
<table>
<tr><td>related ID:<td><input size=8 name=bugid2>
<!--<tr><td>two-way:<td><input type=checkbox name=two_way checked>-->
<tr><td>comment:<td><input name=type size=90 max=500>
<tr><td colspan=2><input class=btn type=submit value="Add">
<tr><td colspan=2>&nbsp;
<tr><td colspan=2>&nbsp;<span runat="server" class='err' id="add_err"></span>
</table>
<input type=hidden name="id" value=<% Response.Write(Convert.ToString(bugid));%>>
<input type=hidden name="action" value="add">

</form>
<% } %>

</td></tr></table>

</p>
<%

if (ds.Tables[0].Rows.Count > 0)
{
	SortableHtmlTable.create_from_dataset(
		Response, ds, "", "", false);

}
else
{
	Response.Write ("No related " + Util.get_setting("PluralBugLabel","bugs"));
}

%>
</div>
</body>
</html>