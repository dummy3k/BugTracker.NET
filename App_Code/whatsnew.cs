/*
Copyright 2002-2009 Corey Trager
Distributed under the terms of the GNU General Public License
*/

using System;
using System.Web;
using System.Collections.Generic;

namespace btnet
{

	public class WhatsNew
	{

		static object mylock = new Object();
		static long prev_seconds = 0;
		public const long ten_million = 10000000; 
		
		public static void add_news(int bugid, string desc, string action, Security security)
		{

			if (btnet.Util.get_setting("EnableWhatsNewPage","0") == "1")
			{

				long seconds = DateTime.Now.Ticks / ten_million;
				if (seconds == prev_seconds)
				{
					seconds++; // prevent dupes, even if we have to lie.
				}
				prev_seconds = seconds;
				
				BugNews bn = new BugNews();
				bn.seconds = seconds;
				bn.seconds_string = Convert.ToString(seconds);
				bn.bugid = Convert.ToString(bugid);
				bn.desc = desc;
				bn.action = action;
				bn.who = security.user.username;

				// create the list if necessary
				lock(mylock)
				{
					List<BugNews> list = (List<BugNews>) HttpContext.Current.Application["whatsnew"];

					if (list == null)
					{
						list = new List<BugNews>();
						HttpContext.Current.Application["whatsnew"] = list;
					}

					list.Add(bn);

				}

			}

		}

	}

	public class BugNews
	{
		public long seconds;
		public string seconds_string;
		public string bugid;
		public string desc;
		public string action;
		public string who;
	}
	
}


