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
		
		public static void add_news(int id, string desc, string action, Security security)
		{
			if (btnet.Util.get_setting("EnableWhatsNewPage","0") == "1")
			{

				BugNews bn = new BugNews();
				bn.when = DateTime.Now;
				bn.id = id;
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
		public DateTime when;
		public int id;
		public string desc;
		public string action;
		public string who;
	}

}


