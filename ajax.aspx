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
		string sql = @"
/* popup */
select substring(isnull(bp_comment_search,bp_comment),1,400)
from bug_posts
where bp_bug = $id
and isnull(bp_comment_search,bp_comment) is not null
and bp_type in ('received','comment', 'sent')
and bp_hidden_from_external_users = 0
order by bp_date desc";



		sql = sql.Replace("$id",bugid);

		DataSet ds = dbutil.get_dataset(sql);

		// no rows
		if (ds.Tables[0].Rows.Count == 0)
		{
			Response.Write("");
			Response.End();
		}

		StringBuilder sb = new StringBuilder();

		sb.Append(bugid);
		sb.Append(":<br><br>");

		bool first_time = true;

		foreach (DataRow dr in ds.Tables[0].Rows)
		{

			if (first_time)
			{
				first_time = false;
			}
			else
			{
				sb.Append("<hr>");
			}


			string s = (string) dr[0];

			// indicate that there's more text
			if (s.Length == 400)
			{
				s+= "...";
			}

			// preserve line breaks
			s = HttpUtility.HtmlEncode(s);
			s = s.Replace("\n\n","\n");
			s = s.Replace("\n","<br>");

			sb.Append(s);

		}

		Response.Write(sb.ToString());
	}
	else
	{
		Response.Write ("");
	}
}


</script>

