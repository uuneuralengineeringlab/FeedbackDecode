function [labels, features] = generate_labels_for_classifier (Targets, Kinematics, Features, config_trials, type, nbr_classes, threshold)
    
    s1 = size(Targets);
    s_features = size(Features);
    labels = zeros(s1(2), nbr_classes);
    targets = (Kinematics>threshold) |  (Kinematics<-threshold);
    
    
    if type == 1
        % Using config_trials. config trials will tell the trial class
        has_found_peak = 0;
        counter_trial = 1;
        counter = 0;
        
        
        for i = 1:s1(2)
            
            if sum(abs(targets(:, i))) ~= 0
                % try to find where there is movement and assign a value to
                % label according to the config_trials
                has_found_peak = 1;
                labels(i, config_trials(counter_trial, 1)) = 1 ;
                
            else
                % when no movement is found we assign the no movement class
                % and if in the previous trial had movement we add one to
                % the counter_trial

                
                if has_found_peak == 1
                   counter = mod(counter+1, config_trials(counter_trial, 2));
                   if counter == 0
                    counter_trial = counter_trial + 1;
                   end
                   has_found_peak = 0;
                end
                labels(i, nbr_classes) = 1 ;

            end
        end
        
    elseif type == 2
        % assuming that all movements towards 1 is a flexion, extension
        % movements go  towards -1 and neutral movements have no chances
        
        counter_trial = 1;
        counter = 0;
        
        has_achieved_max = 0;
        go_back = 0;

        for i = 1:s1(2)
            if sum(abs(Kinematics(:,i))) ~= 0 
                if has_achieved_max == 1
                    if sum(abs(Kinematics(:,i) - Targets(:,i))<0.2) ==  s1(1) && go_back ==0
                        labels(i, config_trials(counter_trial, 1)) = 1 ;
                        
                    else
                        go_back =1;
                        %flip extension and flexion
                        if sum(Kinematics(:,i)) > 0 %flexion
                            labels(i, config_trials(counter_trial, 1) + (nbr_classes-1)/2) = 1 ;
                        else %extension
                            labels(i, config_trials(counter_trial, 1) - (nbr_classes-1)/2) = 1 ;
                        end                  
                    end
                    
                else
                   if sum(abs(Kinematics(:,i) - Targets(:,i))<0.2) ==  s1(1)
                    has_achieved_max = 1;
                   end
                   
                   labels(i, config_trials(counter_trial, 1)) = 1 ;
                end
                
            else
                labels(i, nbr_classes) = 1;
                if has_achieved_max == 1
                   counter = mod(counter+1, config_trials(counter_trial, 2));
                   if counter == 0
                    counter_trial = counter_trial + 1;
                   end
                end
                
                has_achieved_max = 0;
                go_back = 0;
            end
            
        end 
        
    else
        labels = [];
        features = [];
        disp('Error')
        return
        
    end
    
%     padded_features = [zeros(s_features(1), window_size-1), Features];
%     windowed_features = zeros(s1(2), s_features(1), window_size);
%     
%     for i = window_size+1:s1(2) + window_size
%         windowed_features(i-window_size,:, :) = padded_features(:, i-window_size:i-1);     
%     end
    
    
    features = Features;

end