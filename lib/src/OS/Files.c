/* file generated by oo2c -- do not edit */
#include <errno.h>
#include <string.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <stddef.h>
#include <stdlib.h>
#include <unistd.h>

#include "__oo2c.h"
#include "__config.h"
#include "OS/Files.d"

#define BUFFER_SIZE 1024

void OS_Files__ErrorContextDesc_GetTemplate(OS_Files__ErrorContext context, Msg__Msg msg, Msg__LString templ, OOC_LEN templ_0d) {
  char *str;
  OOC_INT32 res = msg->code;
  
  if (res == OS_Files__accessDenied) {
    str = "No write permission for parent directory";
  } else if (res == OS_Files__fileExists) {
    str = "A file of this name already exists";
  } else if (res == OS_Files__writeError) {
    str = "Write error";
  } else if (res == OS_Files__fileBusy) {
    str = "File in use";
  } else if (res == OS_Files__noSuchFile) {
    str = "File does not exist";
  }

  _copy_8to16(str, templ, templ_0d);
  if (msg->attribList) {
    Msg__Attribute attr;
    OOC_CHAR16 eol[2] = {(OOC_CHAR16)CharClass__eol, (OOC_CHAR16)0};
    OOC_CHAR16 str16[Msg__sizeAttrName+1];
    
    attr = msg->attribList;
    while (attr) {
      LongStrings__Append(eol, 2, templ, templ_0d);
      _copy_8to16((char*)attr->name, str16, strlen((char*)attr->name)+1);
      LongStrings__Append(str16, Msg__sizeAttrName+1, templ, templ_0d);
      _copy_8to16("=${", str16, Msg__sizeAttrName+1);
      LongStrings__Append(str16, Msg__sizeAttrName+1, templ, templ_0d);
      _copy_8to16((char*)attr->name, str16, Msg__sizeAttrName+1);
      LongStrings__Append(str16, Msg__sizeAttrName+1, templ, templ_0d);
      _copy_8to16("}", str16, Msg__sizeAttrName+1);
      LongStrings__Append(str16, Msg__sizeAttrName+1, templ, templ_0d);
      attr = attr->nextAttrib;
    }
  }
}


static Msg__Msg get_error(const OS_Files__Path path) {
  Msg__Msg msg;
  OOC_INT32 code;
  
  switch (errno) {
  case EACCES: code = OS_Files__accessDenied; break;
  case EBUSY: code = OS_Files__fileBusy; break;
  case EEXIST: code = OS_Files__fileExists; break;
  case ENOENT: code = OS_Files__noSuchFile; break;
  default: code = OS_Files__writeError;
  }
  
  msg = Msg__New((Msg__Context)OS_Files__errorContext, code);
  DYN_TBCALL(Msg,MsgDesc,SetStringAttrib,msg,
	     (msg, (const OOC_CHAR8*)"path", 5, (OOC_CHAR8*)path));
#if HAVE_STRERROR
  DYN_TBCALL(Msg,MsgDesc,SetStringAttrib,msg,
	     (msg, (const OOC_CHAR8*)"errstr", 7, (OOC_CHAR8*)strerror(errno)));
#endif
  DYN_TBCALL(Msg,MsgDesc,SetIntAttrib,msg,
	     (msg, (const OOC_CHAR8*)"errno", 6, (OOC_INT32)errno));
  return msg;
}


void OS_Files__mkdir(const OS_Files__Path path, OOC_LEN path_0d,
                     OS_Files__Mode mode, Msg__Msg *res) {
  int rc;

  rc = mkdir((const char*)path, mode);
  if (rc) {
    *res = get_error(Msg__GetStringPtr(path, path_0d));
  } else {
    *res = OS_Files__done;
  }
}

void OS_Files__makedirs(const OS_Files__Path path, OOC_LEN path_0d,
                        OS_Files__Mode mode, Msg__Msg *res) {
  int rc;
  struct stat sbuf;
  
  if (path[0] == '\000') {	/* empty path --> no operation */
    *res = OS_Files__done;
    return;
  }
  
  rc = stat((const char*)path, &sbuf);
  if (rc) {			/* stat failure: file does not exist */
    OOC_CHAR8 ppath[BUFFER_SIZE];
    int i;
    int last = 0;
    
    for (i = 0; (i < BUFFER_SIZE) && (path[i] != '\000'); i++) {
      ppath[i] = path[i];
      if ((path[i] == '/') && (i > 0) && (path[i-1] != '/')) {
	last = i;
      }
    }
    ppath[last] = '\000';
    OS_Files__makedirs(ppath, BUFFER_SIZE, mode, res);
    if (*res == OS_Files__done) {
      OS_Files__mkdir(path, path_0d, mode, res);
    }
    
  } else {			/* stat successful: file exists */
    if (S_ISDIR(sbuf.st_mode)) {
      *res = OS_Files__done;	/* path exists and is directory */
    } else {
      /* path is not directory: let mkdir get the error message */
      OS_Files__mkdir(path, path_0d, mode, res);
    }
  }
}

void OS_Files__remove(const OS_Files__Path path, OOC_LEN path_0d,
                      Msg__Msg *res) {
  int rc;

  rc = unlink((const char*)path);
  if (rc) {
    *res = get_error(Msg__GetStringPtr(path, path_0d));
  } else {
    *res = OS_Files__done;
  }
}

void OS_Files_init(void) {
  OS_Files__errorContext = 
    RT0__NewObject(OOC_TYPE_DESCR(OS_Files,ErrorContextDesc));
  Msg__InitContext((Msg__Context)OS_Files__errorContext, 
		   (const OOC_CHAR8*)"OS:Files", 15);
}