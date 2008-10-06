<%@ Page language="C#"%>
<!--
Copyright 2002-2008 Corey Trager
Distributed under the terms of the GNU General Public License
-->
<!-- #include file = "inc.aspx" -->

<script language="C#" runat="server">


///////////////////////////////////////////////////////////////////////
void Page_Load(Object sender, EventArgs e)
{
	Util.do_not_cache(Response);

	if (btnet.Util.get_setting("EnableWhatsNew","1") == "0")
	{
		Response.Write("no news");
		Response.End();
	}

	List<BugNews> list = (List<BugNews>) Application["whatsnew"];
	if (list == null)
	{
		Response.Write("no news");
		Response.End();
	}

	StringBuilder sb = new StringBuilder();

	sb.Append("<table>");

	for (int i = list.Count - 1; i > -1; i--)
	{
		BugNews news = list[i];

		sb.Append("<tr>");

		sb.Append("<td>");
		sb.Append(Convert.ToString(news.when));

		sb.Append("<td>");
		sb.Append(Convert.ToString(news.id));

		sb.Append("<td>");
		sb.Append(news.desc);

		sb.Append("<td>");
		sb.Append(news.action);

		sb.Append("<td>");
		sb.Append(news.who);

	}

	sb.Append("</table>");
	Response.Write(sb.ToString());

}

</script>