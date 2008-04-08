<%@ Page language="C#"%>
<!--
Copyright 2002-2008 Corey Trager
Distributed under the terms of the GNU General Public License
-->
<!-- #include file = "inc.aspx" -->

<script language="C#" runat="server">

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

	if (!security.user.is_guest)
	{
		if (Request.QueryString["ses"] != (string) Session["session_cookie"])
		{
			Response.Write ("session in URL doesn't match session cookie");
			Response.End();
		}
	}

	DataView dv = (DataView) Session["bugs"];
	if (dv == null)
	{
		Response.End();
	}

	int bugid = Convert.ToInt32(Util.sanitize_integer(Request["bugid"]));

	int permission_level = Bug.get_bug_permission_level(bugid, security);
	if (permission_level == Security.PERMISSION_NONE)
	{
		Response.End();
	}

	for (int i = 0; i < dv.Count; i++)
	{
		if ((int)dv[i][1] == bugid)
		{
			int flag = Convert.ToInt32(Util.sanitize_integer(Request["flag"]));
			dv[i][2] = flag;

			if (flag == 0)
			{
				// delete
				sql = "delete from bug_user_flags where fl_bug = $bg and fl_user = $us";
			}
			else if (flag == 1)
			{
				// insert
				sql = "insert into bug_user_flags (fl_bug, fl_user, fl_flag) values($bg, $us, 1)";
			}
			else
			{
				// update
				sql = "update bug_user_flags set fl_flag = $fl where fl_bug = $bg and fl_user = $us";
			}

			sql = sql.Replace("$bg", Convert.ToString(bugid));
			sql = sql.Replace("$us", Convert.ToString(security.user.usid));
			sql = sql.Replace("$fl", Convert.ToString(flag));

			try
			{
				dbutil.execute_nonquery(sql);
			}
			catch (System.Data.SqlClient.SqlException ex)
			{
				if (ex.Message.IndexOf("Cannot insert duplicate") > -1)
				{
					// User has two browser windows open
				}
				else
				{
					throw ex;
				}
			}
			break;
		}
	}

}



</script>