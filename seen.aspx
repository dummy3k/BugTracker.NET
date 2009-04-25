<%@ Page language="C#"%>
<!--
Copyright 2002-2008 Corey Trager
Distributed under the terms of the GNU General Public License
-->
<!-- #include file = "inc.aspx" -->

<script language="C#" runat="server">

String sql;

Security security;

///////////////////////////////////////////////////////////////////////
void Page_Load(Object sender, EventArgs e)
{
	Util.do_not_cache(Response);
	
	security = new Security();
	security.check_security( HttpContext.Current, Security.ANY_USER_OK);

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
			int seen = Convert.ToInt32(Util.sanitize_integer(Request["seen"]));
			dv[i]["$SEEN"] = seen;

			if (seen == 0)
			{
				// delete
				sql = "delete from bug_user_seen where sn_bug = $bg and sn_user = $us";
			}
			else
			{
				// insert
				sql = "insert into bug_user_seen values($bg, $us, 1)";
			}

			sql = sql.Replace("$bg", Convert.ToString(bugid));
			sql = sql.Replace("$us", Convert.ToString(security.user.usid));

			try
			{
				btnet.DbUtil.execute_nonquery(sql);
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