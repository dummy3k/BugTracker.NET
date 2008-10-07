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

	sb.Append("<table border=1 class=datat><tr>");
	sb.Append("<td class=datah>when");
	sb.Append("<td class=datah>id");
	sb.Append("<td class=datah>desc");
	sb.Append("<td class=datah>action");
	sb.Append("<td class=datah>user");

	long ticks_now = DateTime.Now.Ticks;

	for (int i = list.Count - 1; i > -1; i--)
	{
		if (i == list.Count-101)
		{
			break; // just the most recent 100
		}

		BugNews news = list[i];

		sb.Append("<tr>");

		TimeSpan ts = new TimeSpan(ticks_now - news.when.Ticks);

		if (ts.Minutes < 1)
		{
			sb.Append("<td class=datad style='background:red;'>");
		}
		else if (ts.Minutes < 2)
		{
			sb.Append("<td class=datad style='background:orange;'>");
		}
		else if (ts.Minutes < 3)
		{
			sb.Append("<td class=datad style='background:yellow;'>");
		}
		else
		{
			sb.Append("<td class=datad>");
		}
		sb.Append(how_long_ago(ts));

		sb.Append("<td class=datad>");
		sb.Append(Convert.ToString(news.id));

		sb.Append("<td class=datad><a href=edit_bug.aspx?id=");
		sb.Append(Convert.ToString(news.id));
		sb.Append(">");
		sb.Append(news.desc);
		sb.Append("</a>");

		sb.Append("<td class=datad>");
		sb.Append(news.action);

		sb.Append("<td class=datad>");
		sb.Append(news.who);

	}

	sb.Append("</table>");
	Response.Write(sb.ToString());

}

string how_long_ago(TimeSpan ts)
{

	// From http://stackoverflow.com/questions/11/how-do-i-calculate-relative-time#12


	double delta = ts.TotalSeconds;

	if (delta < 60)
	{
	  return ts.Seconds == 1 ? "1 second ago" : ts.Seconds + " seconds ago";
	}
	if (delta < 120)
	{
	  return "1 minute ago";
	}
	if (delta < 2700) // 45 * 60
	{
	  return ts.Minutes + " minutes ago";
	}
	if (delta < 5400) // 90 * 60
	{
	  return "1 hour ago";
	}
	if (delta < 86400) // 24 * 60 * 60
	{
	  return ts.Hours + " hours ago";
	}
	if (delta < 172800) // 48 * 60 * 60
	{
	  return "yesterday";
	}
	if (delta < 2592000) // 30 * 24 * 60 * 60
	{
	  return ts.Days + " days ago";
	}
	if (delta < 31104000) // 12 * 30 * 24 * 60 * 60
	{
	  int months = Convert.ToInt32(Math.Floor((double)ts.Days / 30));
	  return months <= 1 ? "1 month ago" : months + " months ago";
	}
	int years = Convert.ToInt32(Math.Floor((double)ts.Days / 365));
	return years <= 1 ? "1 year ago" : years + " years ago";

}

</script>