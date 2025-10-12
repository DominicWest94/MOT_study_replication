function [outputMovie,objLocSave] = MOTmovie(movieLength,numObjs,frameSize,objSpeed,angleSD,objSize,objBuffer,write)

%makes a movie (outputMovie) and an object reference array (objLocSave).
%outputMovie is a 4 dimension array used to save an animation of the
%tracking movie. objLocSave is a x by y by object (1-numObjs) by time
%(frame) array that stores the x and y locations of each object on each
%frame of the animation.

%clear all
% movieLength = 300; % number of frames in movie
% numObjs = 8;
% frameSize = [600 600]; % in pixels
% objSpeed = 8; % pixels/frame
% angleSD = 10; % SD of distribution that is used to introduce variability into the motion
% objSize=10;
% objBuffer=25;

sampleRate=1; % times per frame that positions will be calculated
%objSpeed=objSpeed/sampleRate;
%
dir=[-1,1];
frameDur=1/60; %duration of frame in GIF output of movie (DONT CHANGE)
push = 40; % amount of repelling

if length(frameSize)==1
    frameSize = [frameSize,frameSize];
end

% x=15;
% y=15;
% for i=1:numObjs
%     x=x+30;
%     y=y+13;
%     objLoc(:,:,i)=[x,y];
%     vAng(i)=x+30;
%     xCom = sind(vAng(i))*objSpeed; %calculate X component of object velocity
%     yCom = cosd(vAng(i))*objSpeed; % calculate Y component of object velocity
%     objVel(:,:,i) = [xCom,yCom]; % record random velocity for each object
% end

trackMovie(:,:,1,movieLength) = zeros(frameSize(2),frameSize(1)); % create new empty image array for movie
for frame=1:movieLength*sampleRate
    for obj=1:numObjs % loop for determining speeds/position of objects
        if frame == 1
            objLoc(:,:,obj) = [randsample(frameSize(1)-objSize,1),randsample(frameSize(2)-objSize,1)]; % get random x,y coord
            problem=1;
            while problem>0;
                problem=1;
                for o=1:obj
                    dist = sqrt((objLoc(1,1,o)-objLoc(1,1,obj))^2+(objLoc(1,2,o)-objLoc(1,2,obj))^2);
                    if o~=obj
                        if dist<=(objBuffer*2)
                            problem=problem+1;
                        end
                    end
                end
                if problem==1;
                    problem=0;
                else
                    objLoc(:,:,obj) = [randsample(frameSize(1)-objSize,1),randsample(frameSize(2)-objSize,1)]; % get random x,y coord
                end
            end
            
            vAng(obj) = unidrnd(360);
            xCom = sind(vAng(obj))*objSpeed; %calculate X component of object velocity
            yCom = cosd(vAng(obj))*objSpeed; % calculate Y component of object velocity
            objVel(:,:,obj) = [xCom,yCom]; % record random velocity for each object
        else
            if vAng(obj)>360
                vAng(obj)=vAng(obj)-360;
            elseif vAng<0
                vAng(obj)=vAng(obj)+360;
            end
            vAng(obj) = vAng(obj)+randn*angleSD;
            xCom = sind(vAng(obj))*objSpeed; %calculate X component of object velocity
            yCom = cosd(vAng(obj))*objSpeed; % calculate Y component of object velocity
            objVel(:,:,obj) = [xCom,yCom]; % record random velocity for each object
        end
    end
    for obj=1:numObjs % loop for correcting collisions and drawing of objects
        % check object-object collisions
        if obj<numObjs
            for o=obj+1:numObjs %% keep objects away from eachother by repelling proportional to the proximity of each (when within a certain distance)
                checkOx=round(objLoc(1,1,o)+objVel(1,1,o)); % calculate position of object O on next frame
                checkOy=round(objLoc(1,2,o)+objVel(1,2,o));
                checkObjx=round(objLoc(1,1,obj)+objVel(1,1,obj)); % calculate position of current Obj on next frame
                checkObjy=round(objLoc(1,2,obj)+objVel(1,2,obj));
                dist = sqrt((checkObjx-checkOx)^2+(checkObjy-checkOy)^2); % find distance between object o and current object (obj)on next frame
                if dist<(objBuffer*2)
                    vAng(obj)=vAng(obj)-180;
                    vAng(o)=vAng(o)-180;
                    xCom = sind(vAng(obj))*objSpeed; %calculate X component of object velocity
                    yCom = cosd(vAng(obj))*objSpeed; % calculate Y component of object velocity
                    objVel(:,:,obj) = [xCom,yCom]; % record random velocity for each object
                    xCom = sind(vAng(o))*objSpeed; % calculate X component of object velocity
                    yCom = cosd(vAng(o))*objSpeed; % calculate Y component of object velocity
                    objVel(:,:,o) = [xCom,yCom]; % record random velocity for each object
                end
            end
        end
        if ((objLoc(1,1,obj)+objVel(1,1,obj)) > frameSize(1)-objSize) % check right horizontal boundary
            vAng(obj)=360-vAng(obj);
            xCom = sind(vAng(obj))*objSpeed; %calculate X component of object velocity
            yCom = cosd(vAng(obj))*objSpeed; % calculate Y component of object velocity
            objVel(:,:,obj) = [xCom,yCom]; % record random velocity for each object
        elseif ((objLoc(1,1,obj)+objVel(1,1,obj)) < objSize) % check left horizontal boundary
            vAng(obj)=360-vAng(obj);
            xCom = sind(vAng(obj))*objSpeed; %calculate X component of object velocity
            yCom = cosd(vAng(obj))*objSpeed; % calculate Y component of object velocity
            objVel(:,:,obj) = [xCom,yCom]; % record random velocity for each object
        elseif ((objLoc(1,2,obj)+objVel(1,2,obj)) > frameSize(2)-objSize) % check bottom boundary
            vAng(obj)=360-vAng(obj)+180;
            xCom = sind(vAng(obj))*objSpeed; %calculate X component of object velocity
            yCom = cosd(vAng(obj))*objSpeed; % calculate Y component of object velocity
            objVel(:,:,obj) = [xCom,yCom]; % record random velocity for each object
        elseif  ((objLoc(1,2,obj)+objVel(1,2,obj)) < objSize) %check top boundary
            vAng(obj)=360-vAng(obj)+180;
            xCom = sind(vAng(obj))*objSpeed; %calculate X component of object velocity
            yCom = cosd(vAng(obj))*objSpeed; % calculate Y component of object velocity
        end
        objLoc(1,1,obj) = round(objLoc(1,1,obj)+objVel(1,1,obj)); % current X position of object
        objLoc(1,2,obj) = round(objLoc(1,2,obj)+objVel(1,2,obj)); % current Y position of object
        if objLoc(1,1,obj) < objSize % in case any of the objects somehow sneak past borders
            objLoc(1,1,obj) = objSize;
        elseif objLoc(1,1,obj) > frameSize(1)-objSize
            objLoc(1,1,obj) = frameSize(1)-objSize
        elseif objLoc(1,2,obj) < objSize;
            objLoc(1,2,obj)= objSize;
        elseif objLoc(1,2,obj) > frameSize(2)-objSize
            objLoc(1,2,obj) = frameSize(2)-objSize;
        end
        if mod(frame,sampleRate)==0
            for x=objLoc(1,1,obj)-objBuffer:objBuffer+objLoc(1,1,obj)
                for y=objLoc(1,2,obj)-objBuffer:objBuffer+objLoc(1,2,obj)
                    %for x=objLoc(1,1,obj)-objSize:objSize+objLoc(1,1,obj)
                    %    for y=objLoc(1,2,obj)-objSize:objSize+objLoc(1,2,obj)
                    dist = sqrt((x-objLoc(1,1,obj))^2+(y-objLoc(1,2,obj))^2);
                    if dist > objSize
                        if x>0&y>0&x<(frameSize(1))&y<frameSize(2)
                            if trackMovie(y,x,1,frame/sampleRate)==0
                                trackMovie(y,x,1,frame/sampleRate)=0;
                            end
                        end
                    else
                        if x>0&y>0&x<frameSize(1)&y<frameSize(2)
                            if dist<objSize
                                trackMovie(y,x,1,frame/sampleRate)=1;% set the pixels where objects exist to 1
                            end
                        end
                    end
                    %if dist == objBuffer % draws grey circles around each dot to measure buffer
                    %    if x>0&y>0&x<(frameSize(1))&y<frameSize(2)
                    %        if trackMovie(y,x,1,frame/sampleRate)==0
                    %            trackMovie(y,x,1,frame/sampleRate)=1;
                    %        end
                    %    end
                    %end
                end
            end
        end
    end
    if mod(frame,sampleRate)==0
        objLocSave(:,:,:,frame/sampleRate)=objLoc;
    end
end

if write
    outputMovie=trackMovie;
    outputMovie(find(outputMovie(:,:,:)==1))=255;
    imwrite(outputMovie,sprintf('MOTmovie%d',objSpeed),'gif','DelayTime',frameDur);
    
else
    outputMovie = nan;
end


end