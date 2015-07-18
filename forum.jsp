<%@ page contentType="text/html;charset=gbk" errorPage="error.jsp"%>
<%@ page import="java.util.ArrayList,java.util.Date"%>
<%@ page import="com.hongshee.ejforum.util.PageUtils"%>
<%@ page import="com.hongshee.ejforum.util.AppUtils"%>
<%@ page import="com.hongshee.ejforum.common.ForumSetting"%>
<%@ page import="com.hongshee.ejforum.common.IConstants"%>
<%@ page import="com.hongshee.ejforum.common.CacheManager"%>
<%@ page import="com.hongshee.ejforum.data.UserDAO.UserInfo"%>
<%@ page import="com.hongshee.ejforum.data.BoardDAO.BoardVO"%>
<%@ page import="com.hongshee.ejforum.data.SectionDAO.SectionVO"%>
<%@ page import="com.hongshee.ejforum.data.TopicDAO"%>
<%@ page import="com.hongshee.ejforum.data.TopicDAO.TopicInfo"%>
<%@ page import="com.hongshee.ejforum.data.GroupDAO.GroupVO"%>
<%
	UserInfo userinfo = PageUtils.getSessionUser(request);
	
	String sectionID = request.getParameter("sid");
	String boardID = request.getParameter("fid");

	CacheManager cache = CacheManager.getInstance();
	if (sectionID == null)
	{
		BoardVO tmpBoard = cache.getBoard(boardID);
		if (tmpBoard != null)
			sectionID = tmpBoard.sectionID;
		else
		{
			request.setAttribute("errorMsg", "很抱歉，您所要访问的版块不存在");
			request.getRequestDispatcher("/error.jsp").forward(request, response);
			return;
		}	
	}
	
	SectionVO aSection = cache.getSection(sectionID);
	BoardVO aBoard = cache.getBoard(aSection, boardID);
	if (aBoard == null)
	{
		aBoard = cache.getBoard(boardID);
		if (aBoard != null)
		{
			sectionID = aBoard.sectionID;
			aSection = cache.getSection(sectionID);		
		}
		else
		{
			request.setAttribute("errorMsg", "很抱歉，您所要访问的版块不存在");
			request.getRequestDispatcher("/error.jsp").forward(request, response);
			return;
		}	
	}

	String moderators = PageUtils.getModerators(aSection, aBoard);
	String moderatorLink = PageUtils.getModeratorLink(moderators);
	
	GroupVO userGroup = PageUtils.getGroupVO(userinfo, moderators);
	if (!PageUtils.isPermitted(aBoard,userGroup,IConstants.PERMIT_VISIT_FORUM) 
		|| aBoard.allowGroups.indexOf(userGroup.groupID) < 0)
	{
		if (userinfo == null)  // Guest
		{
			String fromPath = request.getRequestURI();
			String queryStr = request.getQueryString();
			if (queryStr != null)
				fromPath = fromPath + "?" + queryStr;
			request.setAttribute("fromPath", fromPath);
			request.getRequestDispatcher("/login.jsp").forward(request, response);
			return;
		}
		else
		{
			request.setAttribute("errorMsg", "很抱歉，您缺乏足够的访问权限");
			request.getRequestDispatcher("/error.jsp").forward(request, response);
			return;
		}
	}

	boolean isModerator = false;
	if (userGroup.groupID == 'A' || userGroup.groupID == 'M' || userGroup.groupID == 'S')
		isModerator = true;

	if (aBoard.state == 'I' && !isModerator)
	{
		request.setAttribute("errorMsg", "很抱歉，此版块已经关闭");
		request.getRequestDispatcher("/error.jsp").forward(request, response);
		return;
	}

	String ctxPath = request.getContextPath();
	String serverName = request.getServerName();
	if (!ctxPath.equals("/"))
		serverName = serverName + ctxPath;

	ForumSetting setting = ForumSetting.getInstance();
	
	String strPageNo = request.getParameter("page");
	int pageNo = PageUtils.getPageNo(strPageNo);
	int pageRows = setting.getInt(ForumSetting.DISPLAY, "topicsPerPage");

	StringBuilder sbuf = new StringBuilder("./forum.jsp?sid=");
	sbuf.append(sectionID).append("&fid=").append(boardID);

	String spec = request.getParameter("spec");
	if (spec == null || spec.length() == 0)
		spec = "all";
	else
		sbuf.append("&spec=").append(spec);
		
	String forumName = setting.getForumName();
	String title = PageUtils.getTitle(forumName);
	String[] menus = PageUtils.getHeaderMenu(request, userinfo);

	String sortField = request.getParameter("sort");
	if (sortField == null || sortField.length() == 0)
	{
		sortField = aBoard.sortField;
		if (sortField == null || sortField.length() == 0)
			sortField = "lastPostTime";
	}
	else
		sbuf.append("&sort=").append(sortField);

	String baseUrl = response.encodeURL(sbuf.toString());

	sbuf.setLength(0);
	sbuf.append("./forum-").append(sectionID).append("-").append(boardID);
	String forumUrl = response.encodeURL(sbuf.toString() + "-1.html");
	String homeUrl = response.encodeURL("./index.jsp");
	String forumStyle = PageUtils.getForumStyle(request, response, aBoard);
	
	String rssStyle = setting.getString(ForumSetting.FUNCTIONS, "RssStyle");
	String feedUrl = null;
	
	if (rssStyle.equals("B"))
		feedUrl = sbuf.toString() + "-0.xml";
	else	
		feedUrl = sbuf.toString() + "-1.xml";

    ArrayList sections = cache.getSections();
	
	String showSectionLink = setting.getString(ForumSetting.DISPLAY, "showSectionLink");
	String sectionLink = null;
	if (showSectionLink.equalsIgnoreCase("yes"))
	{
		sbuf.setLength(0);
		sbuf.append(" &raquo;&nbsp; <A href=\"./index.jsp?sid=").append(sectionID)
			.append("\">").append(aSection.sectionName).append("</A>");
		sectionLink = response.encodeURL(sbuf.toString());
	}

	Object[] result = TopicDAO.getInstance().getTopicList(aSection, aBoard, sortField, spec, baseUrl, pageNo, pageRows);
%>
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<HTML xmlns="http://www.w3.org/1999/xhtml">
<HEAD>
<TITLE><%= aBoard.boardName %> - <%= title %></TITLE>
<%= PageUtils.getMetas(title, aBoard) %>
<%= PageUtils.getRSSLink(request, forumName, aSection, aBoard) %>
<LINK href="styles/<%= forumStyle %>/ejforum.css" type=text/css rel=stylesheet>
</HEAD>
<BODY onkeydown="if(event.keyCode==27) return false;">
<SCRIPT src="js/common.js" type=text/javascript></SCRIPT>
<DIV class=wrap>
<jsp:include page="head.jsp"></jsp:include>
<!--<DIV id=header>
<%= PageUtils.getHeader(request, title) %>
<%= PageUtils.getHeadAdBanner(request, aBoard) %>
</DIV>
--><%= menus[0] %>
<DIV id=foruminfo>
<DIV id=nav>
<P><A href="<%= homeUrl %>"><%= forumName %></A><%= sectionLink==null?"":sectionLink %> &raquo;&nbsp; 
<%= aBoard.boardName %></P>
<P>版主: <%= moderatorLink==null?"空缺中":moderatorLink %></P></DIV>
<DIV id=headsearch>
<SCRIPT type=text/javascript>
function doSearch() {
	if(trim($('frmsearch').q.value)=='')
	{
		alert('请输入搜索关键字');
		return false;
	}
	frmsearch.submit();
}
</SCRIPT>
<FORM id="frmsearch" name="frmsearch" 
	  action="http://www.google.cn/search" onsubmit="doSearch(); return false;" method=get target="google_window">
<INPUT type=hidden value="GB2312" name=ie> 
<INPUT type=hidden value="GB2312" name=oe> 
<INPUT type=hidden value=zh-CN name=hl> 
<INPUT type=hidden value="<%= serverName %>" name=sitesearch> 
<div onclick="javascript:window.open('http://www.google.cn/')" 
 style="cursor:pointer;float:left;width:70px;height:23px;background: url(images/google.png)! important;background: none; filter: 
 progid:DXImageTransform.Microsoft.AlphaImageLoader(src='images/google.png',sizingMethod='scale')"></div>&nbsp;
<INPUT maxLength=255 size=12 name=q class="search">&nbsp; 
<a href="#" onclick="doSearch(); return false;" style="vertical-align:middle">
<img src="styles/<%= forumStyle %>/images/search.gif" border="0" alt="站内搜索" align="absbottom"/></a>
</FORM></DIV></DIV>
<DIV id=ad_text></DIV>
<%
	if (aBoard.ruleCode != null && aBoard.ruleCode.length() > 0) {
%>
<DIV class="mainbox forumlist" style="padding-top:0px">
<TABLE cellSpacing=0 cellPadding=0>
  <TBODY class="info">
  <TR><TD class="subject">本版规则</TD></TR>
  <TR><TD><%= aBoard.ruleCode %></TD></TR>
  </TBODY></TABLE></DIV>
<%
	}
%>  
<DIV class=pages_btns>
<%
	if (result != null && result[0] != null)
	{
%>	  
	<%= result[0] %>
<%
	}
%>
<SPAN class=postbtn id="newtopic" onmouseover="$('newtopic').id = 'newtopictmp';this.id = 'newtopic';showMenu(this.id);">
<A href="post.jsp?sid=<%= sectionID %>&fid=<%= boardID %>"><IMG alt=发新话题 
src="styles/<%= forumStyle %>/images/newtopic.gif" border=0></A></SPAN>
</DIV>
<UL class="popmenu_popup newtopicmenu" id="newtopic_menu" style="display: none">
<LI><a href="post.jsp?sid=<%= sectionID %>&fid=<%= boardID %>">发新话题</a></LI>		
<LI class="reward"><a href="post.jsp?sid=<%= sectionID %>&fid=<%= boardID %>&act=reward">发布悬赏</a></LI>
</UL>
<DIV id=headfilter>
<UL class=tabs>
  <LI<%= spec.equals("all")?" class=spec":""%>><A href="<%= forumUrl %>">全部</A></LI>
  <LI<%= spec.equals("digest")?" class=spec":""%>><A 
  		href="forum.jsp?sid=<%= sectionID %>&fid=<%= boardID %>&spec=digest">精华</A></LI>
  <LI<%= spec.equals("reward")?" class=spec":""%>><A 
  		href="forum.jsp?sid=<%= sectionID %>&fid=<%= boardID %>&spec=reward">悬赏</A></LI>
  <LI style="border:none"><A title="RSS Feed" href="<%= feedUrl %>" target=_blank>
  	  <IMG alt="RSS Feed" src="images/rss.gif" border="0"></A></LI>
</UL>
</DIV>
<DIV class="mainbox topiclist">
<H1><A class=bold href="<%= forumUrl %>"><%= aBoard.boardName %></A> </H1>
<%
	if (isModerator) {
		sbuf.setLength(0);
		sbuf.append("manage.jsp?sid=").append(sectionID).append("&fid=").append(boardID)
			.append("&page=").append(pageNo);
%>
<FORM name="frmmanage" action="<%= response.encodeURL(sbuf.toString()) %>" method=post>
<%
	}
%>
<TABLE cellSpacing=0 cellPadding=0>
  <THEAD class=category>
  <TR>
    <TD>&nbsp;</TD>
    <TD>主题</TD>
    <TD class=author>作者</TD>
    <TD class=nums>回复/查看</TD>
    <TD class=lastpost>最后发表</TD></TR></THEAD>
<%
	if (result != null && result[1] != null)
	{
		ArrayList topicList = (ArrayList)result[1];

		TopicInfo aTopic = null;
		String topicUrl = null;
		String lastPostUrl = null;
		boolean hasTopTopics = false;
		String userID = null;
		String nickname = null;
		String lastNickname = null;
		String topicIcon = null;
		int hotTopicPosts = setting.getInt(ForumSetting.DISPLAY, "hotTopicPosts");
		int hotTopicVisits = setting.getPInt(ForumSetting.DISPLAY, "hotTopicVisits", 100);
		String spaceURL = response.encodeURL("uspace.jsp?uid=");
		
		for (int i=0; i<topicList.size(); i++)
		{
			aTopic = (TopicInfo)topicList.get(i);
			if (aTopic.topScope == 'N' && hasTopTopics) {
				hasTopTopics = false;
%>			
</TABLE>
<TABLE cellSpacing=0 cellPadding=0>
  <THEAD class=separation>
  <TR>
    <TD>&nbsp;</TD>
    <TD colSpan=4>版块主题</TD></TR></THEAD>
<%
			}
			sbuf.setLength(0);
			sbuf.append("./topic-").append(aTopic.topicID);
			topicUrl = response.encodeURL(sbuf.toString() + "-1.html");
			lastPostUrl = response.encodeURL(sbuf.toString() + "-999.html");
			
			if (aTopic.isHidePost == 'T')
			{
				userID = "";
				nickname = "匿名";
			}
			else
			{
				userID = aTopic.userID;	
				nickname = (aTopic.nickname==null || aTopic.nickname.length()==0) ? userID : aTopic.nickname;
			}
			lastNickname = 
				(aTopic.lastNickname==null || aTopic.lastNickname.length()==0) ? aTopic.lastPostUser : aTopic.lastNickname;

			if (aTopic.state == 'C')
				topicIcon = "folder_lock.gif";
			else if (Integer.parseInt(aTopic.replies) >= hotTopicPosts)
				topicIcon = "folder_hot.gif";
			else if (Integer.parseInt(aTopic.visits) >= hotTopicVisits)
				topicIcon = "folder_hot.gif";
			else
				topicIcon = "folder_common.gif";
%>	
  <TBODY>
  <TR>
    <TD class=folder><A title=新窗口打开 href='<%= topicUrl %>' target=_blank><IMG src="images/<%= topicIcon %>"></A></TD>
    <TD>
<%
			if (aTopic.isDigest == 'T') {
%>	
		<LABEL><IMG alt="精华" src="images/digest.gif" align="absmiddle">&nbsp;</LABEL>
<%
			}
			if (aTopic.topScope != 'N')
			{
				hasTopTopics = true;
%>	
		<LABEL><IMG alt="<%= aTopic.topScope=='1'?"全局置顶":(aTopic.topScope=='2'?"分区置顶":"本版置顶") %>" 
				src="images/top_<%= aTopic.topScope %>.gif" align="absmiddle">&nbsp;</LABEL> 
<%
			}
			if (isModerator) {
%>
		<input class="checkbox" type="checkbox" name="chkTopicID" value="<%= aTopic.topicID %>"/>
<%
			}
			String highColor = null;
			if (aTopic.highColor != null && aTopic.highColor.length() > 0)
			{
				highColor = " style=\"color:" + aTopic.highColor + "\"";
			}
%>		
		<A href='<%= topicUrl %>'<% if(highColor!=null) out.write(highColor); %>><%= aTopic.title %></A> 
<%
			if (aTopic.attachIcon != null) {
			 	if (aTopic.attachIcon.indexOf('I') >= 0) {
					out.write("<LABEL class=\"pic\">(&nbsp;图&nbsp;)&nbsp;</LABEL>");
				}
			 	else if (aTopic.attachIcon.indexOf('F') >= 0) {
					out.write("<LABEL class=\"pic\">(&nbsp;媒&nbsp;)&nbsp;</LABEL>");
				}
				if (aTopic.attachIcon.indexOf('A') >= 0) {
					out.write("<LABEL class=\"attach\">&nbsp;</LABEL>");
				}
			}
			if (aTopic.reward > 0) {
				out.write("<LABEL class=\"reward\">&nbsp;[&nbsp;积分&nbsp;" + aTopic.reward + "&nbsp;");
				if (aTopic.isSolved == 'T')
					out.write("&nbsp;已解决&nbsp;");
				out.write("]</LABEL>");
			}
%>		
		</TD>
    <TD class=author><CITE><A href="<%= spaceURL %><%= userID %>"><%= nickname.length()==0?"游客":nickname %></A> 
      </CITE><EM><%= aTopic.createTime %></EM></TD>
    <TD class=nums><SPAN><%= aTopic.replies %></SPAN> / <EM><%= aTopic.visits %></EM></TD>
    <TD class=lastpost><EM><A href="<%= lastPostUrl %>"><%= aTopic.lastPostTime %></A></EM>
		<CITE>by <A href="<%= spaceURL %><%= aTopic.lastPostUser %>"><%= lastNickname.length()==0?"游客":lastNickname %></A>
		</CITE>
    </TD></TR></TBODY>
<%		
		}
	} 
	else 
	{
%>
	<tbody><tr><td class=folder>&nbsp;</td><td colspan="4">本版块或指定的范围内尚无主题。</td></tr></tbody>
<%
	}
%>	
</TABLE>
<%
	if (isModerator) {
%>
<div class="management">
	<input type="hidden" name="act"/>
	<label><input class="checkbox" type="checkbox" name="chkall" onclick="checkall(this.form, 'chkTopicID')"/> 全选</label>
	<% if (userGroup.rights.indexOf(IConstants.PERMIT_DELETE_POST) >= 0) { %>
		<button onclick="doManage('delete');return false;">删除主题</button>&nbsp;
	<% }
	   if (userGroup.rights.indexOf(IConstants.PERMIT_MOVE_POST) >= 0) { %>
		<button onclick="doManage('move');return false;">移动主题</button>&nbsp;
	<% } %>	
	<button onclick="doManage('highlight');return false;">高亮显示</button>&nbsp;
	<% if (userGroup.rights.indexOf(IConstants.PERMIT_CLOSE_POST) >= 0) { %>
		<button onclick="doManage('close');return false;">关闭/打开主题</button>&nbsp;
	<% } %>
	<button onclick="doManage('top');return false;">置顶/解除置顶</button>&nbsp;
	<button onclick="doManage('digest');return false;">加入/解除精华</button>
<script type="text/javascript">
	function doManage(action) 
	{
		var theform = document.frmmanage;
		var hasCheckedID = false;
		if (typeof(theform.chkTopicID) != "undefined")
		{
			if (typeof(theform.chkTopicID.length) != "undefined")
			{
				for (i=0; i<theform.chkTopicID.length; i++){
					if (theform.chkTopicID[i].checked){
						hasCheckedID = true;
						break;
					}
				}
			}
			else if (theform.chkTopicID.checked)
				hasCheckedID = true;
		}
		if (!hasCheckedID){
			alert("请至少选中一个主题");
			return false;
		}
		theform.act.value = action;
		theform.submit();
	}
</script>
</div>
</FORM>
<%
	}
%>
</DIV>
<DIV class=pages_btns>
<%
	if (result != null && result[0] != null)
	{
%>	  
	<%= result[0] %>
<%
	}
%>
<SPAN class=postbtn id="newtopictmp" onmouseover="$('newtopic').id = 'newtopictmp';this.id = 'newtopic';showMenu(this.id);">
<A href="post.jsp?sid=<%= sectionID %>&fid=<%= boardID %>"><IMG alt=发新话题 
src="styles/<%= forumStyle %>/images/newtopic.gif"></A></SPAN></DIV>
<DIV class=legend id=footfilter><DIV class=jump_sort><form id="frmsort" name="frmsort" action="<%= forumUrl %>" method="post">
<SELECT onchange="if(this.options[this.selectedIndex].value != ''){window.location = this.options[this.selectedIndex].value;}">
<OPTION value="" selected>版块跳转 ...</OPTION> 
<%
	if (sections != null)
	{
		SectionVO tmpSection = null;
		BoardVO tmpBoard = null;
		String tmpUrl = null;
		StringBuilder sb = new StringBuilder();
		
		for (int i=0; i<sections.size(); i++)	
		{
			tmpSection = (SectionVO)sections.get(i);
			if (tmpSection.boardList == null) continue;

			sb.append("<OPTGROUP label=\"").append(tmpSection.sectionName).append("\">\n");
			
			for (int j=0; j<tmpSection.boardList.size(); j++)
			{
				tmpBoard = (BoardVO)tmpSection.boardList.get(j);
				if (tmpBoard.state == 'I' && !isModerator) continue;
				sbuf.setLength(0);
				sbuf.append("./forum-").append(tmpSection.sectionID).append("-").append(tmpBoard.boardID).append("-1.html");
				tmpUrl = response.encodeURL(sbuf.toString());
				sb.append("<OPTION value=\"").append(tmpUrl).append("\">&nbsp; &gt; ")
				  .append(tmpBoard.boardName).append("</OPTION>\n");
			}
			sb.append("</OPTGROUP>");
		}
		out.write(sb.toString());
	}
%>
</SELECT>&nbsp;
<SELECT name="sort" id="sortfield" onchange="$('frmsort').submit();"> 
<OPTION value="lastPostTime" selected>按回复时间排序</OPTION> 
<OPTION value="createTime">按发布时间排序</OPTION> 
<OPTION value="A_lastPostTime">按回复时间排序(升序)</OPTION> 
<OPTION value="A_createTime">按发布时间排序(升序)</OPTION> 
<OPTION value="replies">按回复数量排序</OPTION> 
<OPTION value="visits">按浏览次数排序</OPTION>
<OPTION value="A_replies">按回复数量排序(升序)</OPTION> 
<OPTION value="A_visits">按浏览次数排序(升序)</OPTION></SELECT>
<INPUT type=hidden value="<%= spec %>" name="spec"></form></DIV>
<DIV><LABEL><IMG alt=正常主题 
src="images/folder_common.gif">正常主题</LABEL> <LABEL><IMG alt=热门主题 
src="images/folder_hot.gif">热门主题</LABEL> <LABEL><IMG alt=关闭主题 
src="images/folder_lock.gif">关闭主题</LABEL> </DIV>
</DIV>
<SCRIPT type=text/javascript>
$('sortfield').value = "<%= sortField %>";
</SCRIPT>
</DIV>
<%= menus[1]==null?"":menus[1] %>
<%= menus[2]==null?"":menus[2] %>
<%= PageUtils.getFootAdBanner(request, aBoard) %>
<%= PageUtils.getFooter(request, forumStyle) %>
</BODY></HTML>
