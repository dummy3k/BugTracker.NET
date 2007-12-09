<%@ Page language="C#"%>
<!--
Copyright 2002-2007 Corey Trager
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
	dbutil = new DbUtil();
	security = new Security();
	security.check_security(dbutil, HttpContext.Current, Security.ANY_USER_OK_EXCEPT_GUEST);

	DataView dv = (DataView) Session["bugs"];
	if (dv == null)
	{
		Response.End();
	}


	int bugid = Convert.ToInt32(Util.sanitize_integer(Request["bugid"]));

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
			sql = sql.Replace("$us", Convert.ToString(security.this_usid));
			sql = sql.Replace("$fl", Convert.ToString(flag));

			dbutil.execute_nonquery(sql);
			break;
		}
	}

}



</script>