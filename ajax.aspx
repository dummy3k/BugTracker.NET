<%@ Page language="C#"%>
<!-- #include file = "inc.aspx" -->

<script runat="server">

DbUtil dbutil;
Security security;

///////////////////////////////////////////////////////////////////////
void Page_Load(Object sender, EventArgs e)
{

	Util.do_not_cache(Response);
	dbutil = new DbUtil();
	security = new Security();
	security.check_security(dbutil, HttpContext.Current, Security.ANY_USER_OK);

	string bugid = Util.sanitize_integer(Request["bugid"]);

	// check permission
	if (Bug.get_bug_permission_level(Convert.ToInt32(bugid), security) != Security.PERMISSION_NONE)
	{
		// get the first bug comment or the email that created this bug
		string sql = @"select top 1 substring(bp_comment,0,400), isnull(bp_content_type,'') [bp_content_type] from bug_posts
			where bp_bug = $id
			and bp_type in ('received','comment')
			and bp_hidden_from_external_users = 0
			order by bp_date";

		sql = sql.Replace("$id",bugid);

		DataRow dr = dbutil.get_datarow(sql);

		if (dr != null)
		{

			string s = (string) dbutil.execute_scalar(sql);

			if (s == null)
			{
				Response.Write ("");
			}
			else
			{
				// indicate that there's more text
				if (s.Length == 399)
				{
					s+= "...";
				}

				if ((string) dr["bp_content_type"] == "text/html")
				{
					// don't encode
				}
				else
				{
					// preserve line breaks
					s = HttpUtility.HtmlEncode(s);
					s = s.Replace("\n\n","\n");
					s = s.Replace("\n","<br>");
				}
				Response.Write (s);
			}
		}
		else
		{
			Response.Write ("");
		}
	}
	else
	{
		Response.Write ("");
	}
}


</script>

