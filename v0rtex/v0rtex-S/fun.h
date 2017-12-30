//
//  ViewController.h
//  v0rtex
//
//  Created by Sticktron on 2017-12-07.
//  Copyright © 2017 Sticktron. All rights reserved.
//

#include "v0rtex.h"
#include "kernel.h"
#include "symbols.h"
#include "root-rw.h"
#include "libjb.h"
#include "patchfinder64.h"
#include "v0rtex.h"
#include "amfi.h"
#include <sys/spawn.h>
#include <sys/stat.h>
#include <CommonCrypto/CommonDigest.h>
#include <mach-o/loader.h>
#include <sys/dir.h>
#include <sys/utsname.h>

void start_exploit_v0rtex(void);
