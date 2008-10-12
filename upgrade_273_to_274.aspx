<%@ Page language="C#"%>
<!--
Copyright 2002-2008 Corey Trager
Distributed under the terms of the GNU General Public License
-->
<% @Import Namespace="btnet" %>
<% @Import Namespace="System.Data" %>

<script language="C#" runat="server">

DbUtil dbutil;

///////////////////////////////////////////////////////////////////////
void Page_Load(Object sender, EventArgs e)
{

	Util.do_not_cache(Response);
	dbutil = new DbUtil();

	Random random = new Random();

	string sql = "select us_username, us_id, us_password from users where len(us_password) < 32";


	DataSet ds = dbutil.get_dataset(sql);
	foreach (DataRow dr in ds.Tables[0].Rows)
	{
        System.Threading.Thread.Sleep(10); // give time for the random number to seed differently;
        string us_username = (string) dr["us_username"];
		int us_id = (int) dr["us_id"];
		string us_password = (string) dr["us_password"];
		{
			Response.Write ("encrypting " + us_username + "<br>");
            btnet.Util.update_user_password(dbutil, us_id, us_password);
		}
	}

	Response.Write ("done encrypting unencrypted passwords");

}



</script>