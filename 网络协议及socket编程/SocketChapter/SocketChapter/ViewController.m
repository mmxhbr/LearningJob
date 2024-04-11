//
//  ViewController.m
//  SocketChapter
//
//  Created by xu on 2024/4/11.
//

#import "ViewController.h"
#import <sys/socket.h>
#import <netinet/in.h>
#import <arpa/inet.h>
//#import <CocoaAsyncSocket/GCDAsyncSocket.h>
#define SOCKET_PORT htons(8040)
#define IP_ADDR "127.0.0.1"
#define kMacConnectCount 4

@interface ViewController ()

@property (nonatomic, assign) int clientId;

@property (nonatomic, assign) int serverId;

@property (nonatomic, assign) int clientSocket;


@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    [self createAndConnectSocket];
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        [self recvMsg];
    });
}


/// 创建Socket
- (void)createAndConnectSocket {
    int socketId = socket(AF_INET, SOCK_STREAM, 0);
    self.clientId = socketId;
    if (socketId == -1) {
        NSLog(@"create socket fail");
        return;
    }
    struct sockaddr_in socketAdrr;
    socketAdrr.sin_family = AF_INET;
    socketAdrr.sin_port = SOCKET_PORT;
    struct in_addr socketIn_addr;
    socketIn_addr.s_addr = inet_addr(IP_ADDR);
    socketAdrr.sin_addr = socketIn_addr;
    int result = connect(socketId, (const struct sockaddr *)&socketAdrr, sizeof(socketAdrr));
    if (result != 0) {
        NSLog(@"客户端连接失败");
        return;
    }
}

/// 接受消息
- (void)recvMsg {
    while (true) {
        uint8_t buffers[1024];
        ssize_t sizeLen = recv(self.clientId, buffers, sizeof(buffers), 0);
        NSLog(@"客户端：接收到%zd个字节", sizeLen);
        if (sizeLen == 0) {
            continue;
        }
        NSData *data = [NSData dataWithBytes:buffers length:sizeLen];
        NSString *msg = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        NSLog(@"客户端： %@ 接收到消息：%@", [NSThread currentThread], msg);
    }
}


/// 发送消息
/// - Parameter msg: 待发送消息
- (void)sendMsg:(NSString*)msg {
    if (msg.length <= 0) return;
    const void *buff = msg.UTF8String;
    ssize_t sizelen = write(self.clientId, buff, strlen(buff));
    NSLog(@"客户端：发送%zd字节消息", sizelen);
}


#pragma mark -- 服务端处理

- (void)serverSocket {
    self.serverId = socket(AF_INET, SOCK_STREAM, 0);
    if (self.serverId == -1) {
        NSLog(@"服务端： 服务端创建socket失败");
        return;
    }
    // 绑定socket
    struct sockaddr_in sockAddr;
    sockAddr.sin_family = AF_INET;
    sockAddr.sin_port = htons(8040);
    struct in_addr inAddr;
    inAddr.s_addr = inet_addr("127.0.0.1");
    sockAddr.sin_addr = inAddr;
    bzero(&sockAddr.sin_zero, 8);
    int bindResult = bind(self.serverId, (const struct sockaddr*)&sockAddr, sizeof(sockAddr));
    if (bindResult == -1) {
        NSLog(@"服务端：Socket 绑定失败");
        return;
    }
    // 监听Socket
    int listenResult = listen(self.serverId, kMacConnectCount);
    if (listenResult == -1) {
        NSLog(@"服务端： 监听失败");
        return;
    }
    // 接收消息
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        struct sockaddr_in client_address;
        socklen_t socklen;
        int client_socket = accept(self.serverId, (struct sockaddr*)&client_address, &socklen);
        self.clientSocket = client_socket;
        if (client_socket == -1) {
            NSLog(@"服务端： 接收客户端连接错误");
        } else {
            NSString *acceptInfo = [NSString stringWithFormat:@"客户端 in, socket: %d", client_socket];
            NSLog(@"服务端：%@", acceptInfo);
            [self recvClientMsg:client_socket];
        }
    });
}


- (void)recvClientMsg:(int)clientSocket {
    while (true) {
        char buff[1024] = {0};
        ssize_t sizelen = recv(clientSocket, buff, 1024, 0);
        if (sizelen > 0) {
            NSLog(@"服务端： 客户端来消息了");
            NSData *recvData = [NSData dataWithBytes:buff length:sizelen];
            NSString *recvStr = [[NSString alloc] initWithData:recvData encoding:NSUTF8StringEncoding];
            NSLog(@"服务端：%@", recvStr);
        } else if (sizelen == -1) {
            NSLog(@"服务端： 读取数据失败");
            break;
        } else if (sizelen == 0) {
            NSLog(@"服务端：客户端走了");
            close(clientSocket);
            break;
        }
    }
}

- (void) sendToClientMsg:(NSString*)msg {
    size_t sendResult = write(self.clientSocket, msg.UTF8String, strlen(msg.UTF8String));
    NSLog(@"服务端： 发送%zu字节数据", sendResult);
}


- (void) close:(int)clientSocket {
    int closeResult = close(clientSocket);
    if (closeResult == -1) {
        NSLog(@"服务端：关闭失败");
        return;
    } else {
        NSLog(@"服务端：关闭成功");
    }
}

@end
